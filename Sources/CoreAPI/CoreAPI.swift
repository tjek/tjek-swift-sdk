//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

final public class CoreAPI {
    
    public struct Settings {
        public var key: String
        public var secret: String
        public var baseURL: URL
        public var locale: String
        public var appVersion: String
        
        public init(key: String, secret: String, baseURL: URL, locale: String, appVersion: String) {
            self.key = key
            self.secret = secret
            self.baseURL = baseURL
            self.locale = locale
            self.appVersion = appVersion
        }
    }
    
    public let settings: Settings
    public var logLevel: ShopGunSDK.LogLevel
    
    public init(settings: Settings, logLevel: ShopGunSDK.LogLevel) {
        self.settings = settings
        self.logLevel = logLevel
        
        // TODO: load from file
        self.authState = .unauthorized
        
        regenerateURLSession()
    }
    
    // MARK: - requests
    
    // Takes a CoreAPIRequestable, whose responseType is decodable.
    // generates a URLRequest from the request and performs it on the CoreAPI's URLSession
    // once complete it tries to decode the ResponseType, and return that as a Result .success case
    // if it fails it tries to decode a CoreAPIError to use in the Result's .error case
    @discardableResult public func request<R: CoreAPIRequestable>(_ request: R, completion:((Result<R.ResponseType>)->())?) -> Cancellable {
        print("[ShopGunSDK.CoreAPI] requesting \(request)")
        
        let token = RequestToken(owner: self)
        doRequestOperation(RequestOperation<R>(request: request, token: token, completion: completion))
        
        return token
    }
    
    enum AuthState {
        case unauthorized                     // we do not currently have a valid authSession
        case authorizing                      // we are in the processes of trying to get a valid AuthSession
        case authorized(session: AuthSession) // we have a valid AuthSession
    }
    
    var authState: AuthState {
        didSet {
            print("authState did change!", authState)
            // TODO: some kind of notification?
            if case let .authorized(session) = authState {
                // TODO: save the session to disk
                // TODO: passing clientId to different parts of the SDK?
//                print("[ShopGunSDK.CoreAPI] authorized", session)
                // TODO: check if session token & secret have changed
                regenerateURLSession()
            }
        }
    }
    
    func regenerateURLSession() {
        let authProps: (token: String, secret: String)?
        if case let .authorized(session) = self.authState {
            authProps = (token: session.token, secret: settings.secret)
        } else {
            authProps = nil
        }
        
        self.urlSession = URLSession.forCoreAPI(auth: authProps)
    }
    
    // The Id of the client, as provided by the API whenever it performs a session request
    public var clientId: String? {
        if case let .authorized(session) = authState {
            return session.clientId
        } else {
            // TODO: return from a disk cache
            return nil
        }
    }
    
    // an array of all calls the do a request
    private var pendingDoRequestOps: [RequestToken.Identifier: ()->()] = [:]
    private var activeTasks: [RequestToken.Identifier: Cancellable] = [:]
    
    // how many times in a row we have failed to renew auth
    private var failedAuthRenewCount: Int = 0
    private var urlSession: URLSession!
    
    private func retryRequestOperation<R>(_ requestOp: RequestOperation<R>, after delay: TimeInterval) {
        
        var newRequestOp = requestOp
        newRequestOp.retryCount += 1
        
        // TODO: Use a shared bg queue
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.doRequestOperation(newRequestOp)
        }
    }
    
    private func renewAuthSession() {
        authState = .authorizing
        failedAuthRenewCount = 0
        
        //            print("renewAuthSession")
        // TODO: perform the 'renew' request, not just the 'create' request
        
        let apiKey = settings.key
        let baseURL = settings.baseURL
        let appVersion = settings.appVersion
        let locale = settings.locale
        let clientId = self.clientId
        
        let createReq = CoreAPI.Requests.createAuthSessionRequest(clientId: clientId, apiKey: apiKey)
        
        _ = self.urlSession.performRequest(createReq, baseURL: baseURL, appVersion: appVersion, locale: locale) { [weak self] result in
            switch result {
            case .success(let authSession):
                self?.authState = .authorized(session: authSession)
                
                // on success, clear and perform all the pending requestOps
                let pending = self?.pendingDoRequestOps
                self?.pendingDoRequestOps.removeAll()
                self?.activeTasks.removeAll()
                
                // start each pending requestOp
                pending?.forEach { (_, doRequestOp) in
                    doRequestOp()
                }
            case .error(let err):
                // TODO: what happens when auth fails (network?)
                print("crap, auth error", err)
                break;
            }
        }
    }
    
    private func doRequestOperation<R>(_ requestOp: RequestOperation<R>) {
        // TODO: Do on a shared queue?
        
        let baseURL = settings.baseURL
//        let secret = settings.secret
        let appVersion = settings.appVersion
        let locale = settings.locale
        
        // how to handle the results of performing the requestOp
        let requestOpCompletion: ((Result<R.ResponseType>)->()) = { [weak self] result in
            self?.activeTasks[requestOp.token.id] = nil
            
            switch result {
            case .error(let err as CoreAPIError)
                where err.isRetryable && requestOp.retryCount < requestOp.request.maxRetryCount:
                // The error is retryable (and hasnt been retried too many times) ... so retry it
                var newRequestOp = requestOp
                newRequestOp.retryCount += 1
                
                // TODO: Use a shared bg queue
                DispatchQueue.main.asyncAfter(deadline: .now() + (err.canRetryAfter ?? 0.0)) { [weak self] in
                    self?.doRequestOperation(newRequestOp)
                }
                
            case .error(let err as CoreAPIError)
                where err.requiresRenewedAuthSession && self?.failedAuthRenewCount ?? 0 < 3 && requestOp.retryCount < requestOp.request.maxRetryCount:
                // it is an auth-error that requires the session to be renewed/recreated
                
                // increase the requestOp's retryCount, to avoid repeatedly spamming this request if it keeps failing
                var newRequestOp = requestOp
                newRequestOp.retryCount += 1
                
                self?.addRequestOpToPendingQueue(newRequestOp)
                self?.renewAuthSession()
            case .success(_),
                 .error(_):
                // a success, or a non-specific, non-retryable error
                // ... perform the requestOp's completion handler
                
                requestOp.completion?(result)
            }
        }
        
        // check the state of the auth session
        switch self.authState {
        case .authorized(_):
            
            // perform the request with the current auth session
            let task = self.urlSession.performRequest(requestOp.request, baseURL: baseURL, appVersion: appVersion, locale: locale, completion: requestOpCompletion)
            activeTasks[requestOp.token.id] = task
        case .authorizing:
            // add the requestOp to a pending queue for when the authorizing process completes
            self.addRequestOpToPendingQueue(requestOp)
        case .unauthorized:
            
            // if the request doesnt require auth, just perform it.
            // otherwise, add it to the pending queue
            if requestOp.request.requiresAuth == false {
                let task = self.urlSession.performRequest(requestOp.request, baseURL: baseURL, appVersion: appVersion, locale: locale, completion: requestOpCompletion)
                activeTasks[requestOp.token.id] = task
            } else {
                self.addRequestOpToPendingQueue(requestOp)
            }
            
            // either way, start renewing the authSession by entering the 'authorizing' state
            self.renewAuthSession()
        }
    }
    
    private func addRequestOpToPendingQueue<R>(_ requestOp: RequestOperation<R>) {
        self.pendingDoRequestOps[requestOp.token.id] = { [weak self] in
            self?.doRequestOperation(requestOp)
        }
    }
    
    fileprivate func cancel(token: RequestToken) {
        activeTasks[token.id]?.cancel() // cancel any active network tasks
        // TODO: actually cancel the requests rather than just clearing them
        pendingDoRequestOps[token.id] = nil // remove any pending (waiting for auth) request-ops
    }
}

extension CoreAPI.Settings {
    public static func `default`(key: String, secret: String, locale: String, appVersion: String) -> CoreAPI.Settings {
        return .init(key: key, secret: secret, baseURL: URL(string: "https://api.etilbudsavis.dk")!, locale: locale, appVersion: appVersion)
    }
}

// MARK: -

/// This represents the state of an 'active' request being handled by the CoreAPI
fileprivate struct RequestOperation<RequestType: CoreAPIRequestable> {
    
    var request: RequestType
    var retryCount: Int
    var completion: ((Result<RequestType.ResponseType>) -> ())?
    var token: RequestToken
    
    init(request: RequestType, token: RequestToken, retryCount: Int = 0, completion: ((Result<RequestType.ResponseType>) -> ())?) {
        self.request = request
        self.token = token
        self.retryCount = retryCount
        self.completion = completion
    }
}

fileprivate struct RequestToken: Cancellable {
    typealias Identifier = GenericIdentifier<RequestToken>
    var id: Identifier
    weak var owner: CoreAPI?
    
    init(id: Identifier = .generate(), owner: CoreAPI) {
        self.id = id
        self.owner = owner
    }
    public var hashValue: Int { return id.hashValue }

    func cancel() {
        owner?.cancel(token: self)
    }
}

extension CoreAPI {
    // Simple namespace for keeping Requests
    public struct Requests { private init() {} }
}

extension CoreAPI.Requests {
    
    fileprivate static func renewAuthSessionRequest(clientId: String?) -> CoreAPI.Request<CoreAPI.AuthSession> {
        var params: [String: String] = [:]
        params["clientId"] = clientId
        
        return .init(path: "v2/sessions", method: .PUT, requiresAuth: false, parameters: params, timeoutInterval: 10)
    }
    
    // tokenLife default: 90 days
    fileprivate static func createAuthSessionRequest(clientId: String?, apiKey: String, tokenLife: Int = 7_776_000) -> CoreAPI.Request<CoreAPI.AuthSession> {
        
        var params: [String: String] = [:]
        params["api_key"] = apiKey
        params["token_ttl"] = String(tokenLife)
        params["clientId"] = clientId
        
        return .init(path: "v2/sessions", method: .POST, requiresAuth: false, parameters: params, timeoutInterval: 10)
    }
}

extension URLSession {
    fileprivate static func forCoreAPI(auth:(token: String, secret: String)?) -> URLSession {
        
        let config = URLSessionConfiguration.default
        
        var addedHeaders: [AnyHashable : Any] = [:]
        addedHeaders["Accept-Encoding"] = "gzip"
        // TODO: Real UserAgent
        addedHeaders["User-Agent"] = "LH-DummyUserAgent-Test"
        
        if let auth = auth {
            addedHeaders.merge(signedHTTPHeaders(for: auth), uniquingKeysWith: { (_, new) in new })
        }
        
        config.httpAdditionalHeaders = addedHeaders
        
        let urlSession = URLSession(configuration: config)
        urlSession.sessionDescription = "ShopGunSDK.CoreAPI"
        
        return urlSession
    }
    
    // starts performing a Request, signing it with the token/secret pair
    // This is the most low-level performing of a request
    // TODO: pass in a urlSession owned by CoreAPI
    fileprivate func performRequest<R: CoreAPIRequestable>(_ request: R, baseURL: URL, appVersion: String, locale: String, completion:((Result<R.ResponseType>)->())?) -> Cancellable {
        
        let addedParams = ["api_av": appVersion,
                           "r_locale": locale]
        
        let urlRequest = request.urlRequest(for: baseURL, additionalParameters: addedParams)
        
        let task = self.dataTask(with: urlRequest) { (data, response, error) in
            guard let completion = completion else {
                return
            }
            
            guard let httpStatusCode = (response as? HTTPURLResponse)?.statusCode, let data = data else {
                if let err = error {
                    completion(.error(err))
                } else {
                    // TODO: Real error if no status code _AND_ no data _AND_ no error
                    completion(.error(NSError(domain: "Unknown network error", code: 123, userInfo: nil)))
                }
                return
            }
            
            // client or server error - try to decode the error data
            guard (400...599).contains(httpStatusCode) == false else {
                let error: Error
                if var apiError = try? JSONDecoder().decode(CoreAPIError.self, from: data) {
                    apiError.httpResponse = response
                    error = apiError
                } else {
                    // TODO: Real error if client/server error with unknown data format
                    let reason = HTTPURLResponse.localizedString(forStatusCode: httpStatusCode)
                    print(reason)
                    error = NSError(domain: "Unknown Server/Client Error", code: 123, userInfo: nil)
                }
                
                completion(.error(error))
                return
            }
            
            if let resData: R.ResponseType = try? JSONDecoder().decode(R.ResponseType.self, from: data) {
                completion(.success(resData))
            } else {
                print(String(data: data, encoding: .utf8)!)
                // TODO: Real error if data doesnt match expected response type
                completion(.error(NSError(domain: "Unexpected response type", code: 123, userInfo: nil)))
            }
        }
        task.resume()
        return task
    }
}
