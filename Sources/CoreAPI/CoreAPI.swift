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
    
    public let settings: Settings
    
    internal init(settings: Settings, secureDataStore: ShopGunSDKSecureDataStore) {
        self.settings = settings

        self.authVault = AuthVault(baseURL: settings.baseURL, key: settings.key, secret: settings.secret, secureDataStore: secureDataStore)
        
        // Build the urlSession that requests will be run on
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Accept-Encoding": "gzip",
                                        "User-Agent": CoreAPI.userAgent]
        self.requstURLSession = URLSession(configuration: config)
        self.requstURLSession.sessionDescription = "ShopGunSDK.CoreAPI"

        self.requestOpQueue.name = "ShopGunSDK.CoreAPI.Requests"
        
        self.additionalRequestParams = ["api_av": settings.appVersion,
                                        "r_locale": settings.locale]
    }
    
    private init() { fatalError("You must provide settings when creating the CoreAPI") }
    
    private let authVault: AuthVault
    private let requstURLSession: URLSession
    private let requestOpQueue: OperationQueue = OperationQueue()
    private let queue: DispatchQueue = DispatchQueue(label: "CoreAPI-Queue")
    private let additionalRequestParams: [String: String]
}

// MARK: -

private typealias CoreAPI_PerformRequests = CoreAPI
extension CoreAPI_PerformRequests {
    
    @discardableResult public func request<R: CoreAPIDecodableRequest>(_ request: R, completion:((Result<R.ResponseType>)->())?) -> Cancellable {
        if let completion = completion {
            // convert the Result<Data> into Result<R.ResponseType>
            return requestData(request, completion: { (dataResult) in
                completion(dataResult.decodeJSON())
            })
        } else {
            return requestData(request, completion: nil)
        }
    }
    
    @discardableResult public func requestData(_ request: CoreAPIRequest, completion: ((Result<Data>)->())?) -> Cancellable {
        
        // make a new cancellable token by which we refer to this request from the outside
        let token = CancellableToken(owner: self)
        
        self.queue.async { [weak self] in
            guard let s = self else { return }
            
            ShopGunSDK.log("Requesting \(request.path) \(token.id)", level: .verbose, source: .CoreAPI)
            
            let urlRequest = request.urlRequest(for: s.settings.baseURL, additionalParameters: s.additionalRequestParams)
            
            // make a new RequestOperation and add it to the pending queue
            let reqOp = RequestOperation(id: token.id,
                                         requiresAuth: request.requiresAuth,
                                         maxRetryCount: request.maxRetryCount,
                                         urlRequest: urlRequest,
                                         authVault: s.authVault,
                                         urlSession: s.requstURLSession,
                                         completion:  { (dataResult) in
                                            // Make sure the completion is always called on main
                                            DispatchQueue.main.async {
                                                completion?(dataResult)
                                            }
            })
            s.requestOpQueue.addOperation(reqOp)
        }
    
        return token
    }
}

// MARK: -

private typealias CoreAPI_CancelRequests = CoreAPI
extension CoreAPI_CancelRequests {
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

// MARK: -

extension CoreAPI {
    
    public enum LoginCredentials: Equatable {
        case logout
        case shopgun(email: String, password: String)
        case facebook(token: String)
        
        public static func == (lhs: CoreAPI.LoginCredentials, rhs: CoreAPI.LoginCredentials) -> Bool {
            switch (lhs, rhs) {
            case (.logout, .logout):
                return true
            case let (.shopgun(lhsEmail, lhsPass), .shopgun(rhsEmail, rhsPass)):
                return lhsEmail == rhsEmail && lhsPass == rhsPass
            case let (.facebook(lhsToken), .facebook(rhsToken)):
                return lhsToken == rhsToken
                
            case (.logout, _),
                 (.shopgun(_), _),
                 (.facebook(_), _):
                return false
            }
        }
    }
    
    // A user/provider pair
    public typealias AuthorizedUser = (person: CoreAPI.Person, provider: CoreAPI.AuthorizedUserProvider)
    public enum AuthorizedUserProvider: String, Codable {
        case shopgun    = "etilbudsavis" // TODO: do decoding manually to avoid eta/sgn distinction?
        case facebook   = "facebook"
    }

    public func login(credentials: LoginCredentials) {
        self.queue.async { [weak self] in
            self?.authVault.regenerate(.reauthorize(credentials))
        }
    }
}

// MARK: -

private typealias CoreAPI_Settings = CoreAPI
extension CoreAPI_Settings {
    
    public struct Settings {
        public var key: String
        public var secret: String
        public var baseURL: URL
        public var locale: String
        public var appVersion: String
        
        public init(key: String, secret: String, baseURL: URL, locale: String = Locale.current.identifier, appVersion: String) {
            self.key = key
            self.secret = secret
            self.baseURL = baseURL
            self.locale = locale
            self.appVersion = appVersion
        }
    }
}

extension CoreAPI.Settings {
    public static func `default`(key: String, secret: String, locale: String, appVersion: String) -> CoreAPI.Settings {
        return .init(key: key, secret: secret, baseURL: URL(string: "https://api.etilbudsavis.dk")!, locale: locale, appVersion: appVersion)
    }
}
