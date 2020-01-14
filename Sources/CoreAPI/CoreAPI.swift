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
    
    public let settings: Settings.CoreAPI
    
    public var locale: Locale = Locale.autoupdatingCurrent {
        didSet { self.updateAuthVaultParams() }
    }
    
    internal init(settings: Settings.CoreAPI, dataStore: ShopGunSDKDataStore) {
        self.settings = settings
        
        // Build the urlSession that requests will be run on
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Accept-Encoding": "gzip",
                                        "User-Agent": userAgent()]
        self.requstURLSession = URLSession(configuration: config)
        self.requstURLSession.sessionDescription = "ShopGunSDK.CoreAPI"

        self.requestOpQueue.name = "ShopGunSDK.CoreAPI.Requests"
        
        self.authVault = AuthVault(baseURL: settings.baseURL, key: settings.key, secret: settings.secret, urlSession: self.requstURLSession, dataStore: dataStore)
        
        self.authVault.authorizedUserDidChangeCallback = { [weak self] in self?.authorizedUserDidChange(prevAuthUser: $0, newAuthUser: $1) }
        self.updateAuthVaultParams()
    }
    
    private init() { fatalError("You must provide settings when creating the CoreAPI") }
    
    private let authVault: AuthVault
    private let requstURLSession: URLSession
    private let requestOpQueue: OperationQueue = OperationQueue()
    private let queue: DispatchQueue = DispatchQueue(label: "CoreAPI-Queue")
    private var additionalRequestParams: [String: String] {
        return ["r_locale": self.locale.identifier]
    }
    private func updateAuthVaultParams() {
        self.authVault.additionalRequestParams.merge(self.additionalRequestParams) { (_, new) in new }
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
    
    public static func configure() {
        do {
            guard let settings = try Settings.loadShared().coreAPI else {
                fatalError("Required CoreAPI settings missing from '\(Settings.defaultSettingsFileName)'")
            }
            
            configure(settings)
        } catch let error {
            fatalError(String(describing: error))
        }
    }
    
    /// This will cause a fatalError if KeychainDataStore hasnt been configured
    public static func configure(_ settings: Settings.CoreAPI, dataStore: ShopGunSDKDataStore = KeychainDataStore.shared) {

        if isConfigured {
            Logger.log("Re-configuring CoreAPI", level: .verbose, source: .CoreAPI)
        } else {
            Logger.log("Configuring CoreAPI", level: .verbose, source: .CoreAPI)
        }
        
        _shared = CoreAPI(settings: settings, dataStore: dataStore)
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
            guard let s = self else { return }
            
            var urlRequest = request.urlRequest(for: s.settings.baseURL, additionalParameters: s.additionalRequestParams)
            // add the Accept-Language header
            urlRequest.addValue(Locale.preferredLanguages.joined(separator: ", "), forHTTPHeaderField: "Accept-Language")
            
            // make a new RequestOperation and add it to the pending queue
            let reqOp = RequestOperation(id: token.id,
                                         requiresAuth: request.requiresAuth,
                                         maxRetryCount: request.maxRetryCount,
                                         urlRequest: urlRequest,
                                         authVault: s.authVault,
                                         urlSession: s.requstURLSession,
                                         completion: { (dataResult) in
                                            // Make sure the completion is always called on main
                                            DispatchQueue.main.async {
                                                let duration = Date().timeIntervalSince(start)
                                                Logger.log("\(dataResult.getSuccess() != nil ? "✅" : "❌") Request completed: \(String(format: "%.3fs %.3fkb", duration, Double(dataResult.getSuccess()?.count ?? 0) / 1024 )) '\(request.path)' (\(token.id.rawValue))", level: .performance, source: .CoreAPI)

                                                completion?(dataResult)
                                            }
            })
            s.requestOpQueue.addOperation(reqOp)
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

// MARK: -

extension CoreAPI {
    
    public enum ClientIdentifierType {}
    public typealias ClientIdentifier = GenericIdentifier<ClientIdentifierType>
    
    public enum LoginCredentials: Equatable {
        case logout
        case shopgun(email: String, password: String)
        case facebook(token: String)
    }
    
    // A user/provider pair
    public typealias AuthorizedUser = (person: CoreAPI.Person, provider: CoreAPI.AuthorizedUserProvider)
    public enum AuthorizedUserProvider: String, Codable {
        case shopgun    = "etilbudsavis" // TODO: do decoding manually to avoid eta/sgn distinction?
        case facebook   = "facebook"
    }

    public func login(credentials: LoginCredentials, completion: ((Result<AuthorizedUser, Error>) -> Void)?) {
        self.queue.async { [weak self] in
            
            self?.authVault.regenerate(.reauthorize(credentials), completion: { [weak self] (error) in
                if let user = self?.authorizedUser {
                    completion?(.success(user))
                } else {
                    completion?(.failure(error ?? APIError.unableToLogin))
                }
            })
        }
    }
    
    public var authorizedUser: AuthorizedUser? {
        return self.authVault.currentAuthorizedUser
    }
    
    /// The Id that represents this installation on this device to the CoreAPI.
    /// This will remain constant until the app is removed, or it is reset.
    /// It is created the first time the coreAPI communicates with the server
    public var clientId: ClientIdentifier? {
        return self.authVault.clientId
    }
    
    /// Reset the cached clientId. The user will also be logged out, and the clientId will only be regenerated on future CoreAPI requests.
    public func resetClientId() {
        self.authVault.resetStoredAuthState()
    }
    
    /// The current session token.
    public var sessionToken: String? {
        return self.authVault.sessionToken
    }
    
    fileprivate func authorizedUserDidChange(prevAuthUser: AuthorizedUser?, newAuthUser: AuthorizedUser?) {
        
        switch newAuthUser {
        case let (person, provider)?:
            Logger.log("User (\(provider)) logged In \(person)", level: .debug, source: .CoreAPI)
        case nil:
            Logger.log("User logged out", level: .debug, source: .CoreAPI)
        }
        
        var userInfo: [AnyHashable: Any] = [:]
        userInfo["previous"] = prevAuthUser
        userInfo["current"] = newAuthUser
        
        NotificationCenter.default.post(name: CoreAPI.authorizedUserDidChangeNotification, object: self, userInfo: userInfo)
    }
    
    /**
     The name of the notification that is posted when the authorized user changes.
     
     The UserInfo contains the `previous` and `current` AuthorizedUser tuples.
     - If we are logging in, the `previous` authorized user is nil.
     - If we are logging out, the `current` authorized user is nil.
     */
    public static let authorizedUserDidChangeNotification = Notification.Name("com.shopgun.ios.sdk.coreAPI.authorizedUserDidChange")
}

extension CoreAPI {
    /// Simple namespace for keeping Requests
    public struct Requests { private init() {} }
}
