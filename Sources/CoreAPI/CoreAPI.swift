//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

final public class CoreAPI {
    public typealias TokenProvider = () -> (authToken: String?, appInstallId: String?)
    
    /// Every time a request is made, this TokenProvider is called to ask for the auth token.
    public var tokenProvider: TokenProvider
    
    public let settings: Settings.CoreAPI
    
    public var locale: Locale = Locale.autoupdatingCurrent
    
    internal init(tokenProvider: @escaping TokenProvider, settings: Settings.CoreAPI, dataStore: ShopGunSDKDataStore) {
        self.tokenProvider = tokenProvider
        self.settings = settings
        
        // Build the urlSession that requests will be run on
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Accept-Encoding": "gzip",
                                        "User-Agent": userAgent()]
        self.requstURLSession = URLSession(configuration: config)
        self.requstURLSession.sessionDescription = "ShopGunSDK.CoreAPI"

        self.requestOpQueue.name = "ShopGunSDK.CoreAPI.Requests"
    }
    
    private init() { fatalError("You must provide settings when creating the CoreAPI") }
    
    private let requstURLSession: URLSession
    private let requestOpQueue: OperationQueue = OperationQueue()
    private let queue: DispatchQueue = DispatchQueue(label: "CoreAPI-Queue")
    private var additionalRequestParams: [String: String] {
        return [
            "r_locale": self.locale.identifier
        ]
    }
}

// MARK: -

extension CoreAPI {
    fileprivate static var _shared: CoreAPI?

    public static var shared: CoreAPI {
        guard let coreAPI = _shared else {
            fatalError("Must call `CoreAPI.configure(…)` before accessing `shared`")
        }
        return coreAPI
    }

    public static var isConfigured: Bool {
        return _shared != nil
    }
    
    /// This will cause a fatalError if KeychainDataStore hasnt been configured
    public static func configure(tokenProvider: @escaping TokenProvider = { return (nil, nil) }, settings: Settings.CoreAPI? = nil, dataStore: ShopGunSDKDataStore = KeychainDataStore.shared) {
        do {
            guard let settings = try (settings ?? Settings.loadShared().coreAPI) else {
                fatalError("Required CoreAPI settings missing from '\(Settings.defaultSettingsFileName)'")
            }
            
            if isConfigured {
                Logger.log("Re-configuring CoreAPI", level: .verbose, source: .CoreAPI)
            } else {
                Logger.log("Configuring CoreAPI", level: .verbose, source: .CoreAPI)
            }
            
            _shared = CoreAPI(tokenProvider: tokenProvider, settings: settings, dataStore: dataStore)
        } catch let error {
            fatalError(String(describing: error))
        }
    }
}

// MARK: -

extension CoreAPI {
    
    @discardableResult public func request<R: CoreAPIMappableRequest>(_ request: R, completion: ((Result<R.ResponseType, Error>) -> Void)?) -> Cancellable {
        if let completion = completion {
            // convert the Result<Data> into Result<R.ResponseType>
            return requestData(request, completion: { (dataResult) in
                DispatchQueue.global().async {
                    let start = Date()
                    let mappedResult = request.resultMapper(dataResult)
                    
                    let duration = Date().timeIntervalSince(start)
                    Logger.log("Request response parsed: \(String(format: "%.3fs", duration)) '\(request.path)'", level: .performance, source: .CoreAPI)

                    DispatchQueue.main.async {
                        completion(mappedResult)
                    }
                }
            })
        } else {
            return requestData(request, completion: nil)
        }
    }
    
    @discardableResult public func requestData(_ request: CoreAPIRequest, completion: ((Result<Data, Error>) -> Void)?) -> Cancellable {
        
        // make a new cancellable token by which we refer to this request from the outside
        let token = CancellableToken(owner: self)
        
        Logger.log("Requesting '\(request.path)' (\(token.id.rawValue))", level: .verbose, source: .CoreAPI)
        let start = Date()
        
        self.queue.async { [weak self] in
            guard let self = self else { return }
            
            let (authToken, appInstallId) = self.tokenProvider()
            
            var urlRequest = request
                .urlRequest(for: self.settings.baseURL, additionalParameters: self.additionalRequestParams)
                .signedForCoreAPI(withToken: authToken, appInstallId: appInstallId, apiKey: self.settings.key, apiSecret: self.settings.secret)
            // add the Accept-Language header
            urlRequest.addValue(Locale.preferredLanguages.joined(separator: ", "), forHTTPHeaderField: "Accept-Language")
            
            // make a new RequestOperation and add it to the pending queue
            let reqOp = RequestOperation(id: token.id,
                                         requiresAuth: request.requiresAuth,
                                         maxRetryCount: request.maxRetryCount,
                                         urlRequest: urlRequest,
                                         urlSession: self.requstURLSession,
                                         completion: { (dataResult) in
                                            // Make sure the completion is always called on main
                                            DispatchQueue.main.async {
                                                let duration = Date().timeIntervalSince(start)
                                                Logger.log("\(dataResult.getSuccess() != nil ? "✅" : "❌") Request completed: \(String(format: "%.3fs %.3fkb", duration, Double(dataResult.getSuccess()?.count ?? 0) / 1024 )) '\(request.path)' (\(token.id.rawValue))", level: .performance, source: .CoreAPI)

                                                completion?(dataResult)
                                            }
            })
            self.requestOpQueue.addOperation(reqOp)
        }
    
        return token
    }
}

// MARK: -

extension CoreAPI {
    fileprivate struct CancellableToken: Cancellable {
        
        var id: RequestOperation.Identifier
        private weak var owner: CoreAPI?
        
        init(id: RequestOperation.Identifier = .generate(), owner: CoreAPI) {
            self.id = id
            self.owner = owner
        }
        
        func cancel() {
            owner?.cancelOperation(id: self.id)
        }
    }
    
    fileprivate func cancelOperation(id: RequestOperation.Identifier) {
        self.queue.async { [weak self] in
            let reqOp = self?.requestOpQueue.operations.first(where: {
                ($0 as? RequestOperation)?.id == id
            })
            reqOp?.cancel()
        }
    }
    
    public func cancelAll() {
        self.queue.async { [weak self] in
            self?.requestOpQueue.cancelAllOperations()
        }
    }
}

extension CoreAPI {
    /// Simple namespace for keeping Requests
    public struct Requests { private init() {} }
}

extension URLRequest {
    
    /// Generates a new URLRequest that includes the signed HTTPHeaders, given a token & secret
    func signedForCoreAPI(withToken authToken: String?, appInstallId: String?, apiKey: String, apiSecret: String) -> URLRequest {
        var signedRequest = self
        
        signedRequest.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        signedRequest.setValue(apiSecret, forHTTPHeaderField: "X-Api-Secret")
        
        signedRequest.setValue(authToken.map { "Bearer \($0)" }, forHTTPHeaderField: "Authorization")
        signedRequest.setValue(appInstallId, forHTTPHeaderField: "X-App-Install-Id")

        return signedRequest
    }
}
