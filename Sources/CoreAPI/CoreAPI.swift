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
        
        public init(key: String, secret: String, baseURL: URL, locale: String = Locale.current.identifier, appVersion: String) {
            self.key = key
            self.secret = secret
            self.baseURL = baseURL
            self.locale = locale
            self.appVersion = appVersion
        }
    }
    
    public let settings: Settings
    
    public init(settings: Settings) {
        self.settings = settings
        
        // TODO: load from file
        self.authState = .unauthorized
        
        regenerateURLSession()
    }
    
    // MARK: - Requests
    
    @discardableResult public func request<R: CoreAPIDecodableRequest>(_ request: R, completion:((Result<R.ResponseType>)->())?) -> Cancellable {
        if let completion = completion {
            // convert the Result<Data> into Result<R.ResponseType>
            return requestData(request, completion: { (dataResult) in
                completion(CoreAPI.parseDataResult(dataResult))
            })
        } else {
            return requestData(request, completion: nil)
        }
    }
    
    @discardableResult public func requestData(_ request: CoreAPIRequest, completion: ((Result<Data>)->())?) -> Cancellable {
        
        // make a new cancellable token by which we refer to this request from the outside
        let token = RequestToken(owner: self)
        
        self.queue.async { [weak self] in
            ShopGunSDK.log("Requesting \(request.path)", level: .verbose, source: .CoreAPI)
            
            // make a new RequestOperation and add it to the pending queue
            let reqOp = RequestOperation(request: request, token: token, retryCount: 0, completion: completion)
            self?.activeRequests[token] = reqOp
            
            // try to perfom the requestOp
            self?.attemptToStart(requestOp: reqOp)
        }
        
        return token
    }
    
    public func cancelAll() {
        self.queue.async { [weak self] in
            guard let allTokens = self?.activeRequests.keys else {
                return
            }

            ShopGunSDK.log("Cancelling All Requests (\(allTokens.count) total)", level: .verbose, source: .CoreAPI)
            allTokens.forEach({ $0.cancel() })
        }
    }
    
    // A map of all the running (or pending) RequestOperations
    private var activeRequests: [RequestToken: RequestOperation] = [:]
    
    fileprivate func cancel(token: RequestToken) {
        self.queue.async { [weak self] in
            guard let reqOp = self?.activeRequests[token] else { return }
            
            if let activeTask = reqOp.task {
                activeTask.cancel()
            } else {
                // TODO: perform a real manual cancel
                let cancelError = NSError(domain: "Cancel", code: 123, userInfo: nil)
                reqOp.completion?(.error(cancelError))
            }
            self?.activeRequests[token] = nil
        }
    }
    
    // MARK: - Parsing Methods
    
    // Take the raw API response and turn it into a Result<Data>, parsing any API error json
    private static func parseAPIResponse(data: Data?, response: URLResponse?, error: Error?) -> Result<Data> {
        
        guard let httpStatusCode = (response as? HTTPURLResponse)?.statusCode, let data = data else {
            let resError: Error
            if let err = error {
                resError = err
            } else {
                // TODO: Real error if no status code _AND_ no data _AND_ no error
                resError = NSError(domain: "Unknown network error", code: 123, userInfo: nil)
            }
            return .error(resError)
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
                
                ShopGunSDK.log("Unknown Server/Client Error: '\(reason)'", level: .error, source: .CoreAPI)
                error = NSError(domain: "Unknown Server/Client Error", code: 123, userInfo: nil)
            }
            
            return .error(error)
        }
        
        return .success(data)
    }
    
    // Take a Result<Data>, and try to decode it into a specifically-typed Result
    private static func parseDataResult<R: Decodable>(_ dataResult: Result<Data>) -> Result<R> {
        switch dataResult {
        case .error(let err):
            return .error(err)
        case .success(let data):
            if let resVal: R = try? JSONDecoder().decode(R.self, from: data) {
                return .success(resVal)
            } else {
                ShopGunSDK.log("""
                    Unexpected response type (expected \(R.self)):
                    \(String(data: data, encoding: .utf8) ?? "<UnreadableData>")
                    """, level: .error, source: .CoreAPI)
                
                // TODO: Real error if data doesnt match expected response type
                return .error(NSError(domain: "Unexpected response type", code: 123, userInfo: nil))
            }
        }
    }
    
    
    enum AuthState {
        case unauthorized                     // we do not currently have a valid authSession
        case authorizing                      // we are in the processes of trying to get a valid AuthSession
        case authorized(session: AuthSession) // we have a valid AuthSession
    }
    
    fileprivate var authState: AuthState {
        didSet {
            
            // TODO: some kind of notification?
            switch authState {
            case .unauthorized:
                ShopGunSDK.log("Unauthorized", level: .debug, source: .CoreAPI)
                regenerateURLSession()
                
            case .authorizing:
                // started authorizing
                ShopGunSDK.log("Authorizing...", level: .debug, source: .CoreAPI)
                
            case .authorized(let session):
                
                let oldSession: AuthSession?
                if case .authorized(let oldValSession) = oldValue {
                    oldSession = oldValSession
                } else {
                    oldSession = nil
                }
                
                // TODO: save the session to disk
                // TODO: passing clientId to different parts of the SDK?
                
                ShopGunSDK.log("Authorized \(session)", level: .debug, source: .CoreAPI)
                
                guard oldSession?.token != session.token else {
                    return
                }
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
        
        let config = URLSessionConfiguration.default
        
        var addedHeaders: [AnyHashable : Any] = [:]
        addedHeaders["Accept-Encoding"] = "gzip"
        addedHeaders["User-Agent"] = CoreAPI.userAgent
        
        if let auth = authProps {
            addedHeaders.merge(CoreAPI.signedHTTPHeaders(for: auth), uniquingKeysWith: { (_, new) in new })
        }
        
        config.httpAdditionalHeaders = addedHeaders
        
        let newURLSession = URLSession(configuration: config)
        newURLSession.sessionDescription = "ShopGunSDK.CoreAPI"
        
        self.urlSession = newURLSession
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
    
    // how many times in a row we have failed to renew auth
    private var failedAuthRenewCount: Int = 0
    private var urlSession: URLSession!
    private var queue: DispatchQueue = DispatchQueue(label: "CoreAPI-Queue")
    
    private func renewAuthSession() {
        authState = .authorizing
        failedAuthRenewCount = 0

        ShopGunSDK.log("Renewing AuthSession…", level: .debug, source: .CoreAPI)
        //            print("renewAuthSession")
        // TODO: perform the 'renew' request, not just the 'create' request

        let apiKey = settings.key
        let clientId = self.clientId
        
        let createReq = CoreAPI.Requests.createAuthSessionRequest(clientId: clientId, apiKey: apiKey)

        let urlRequest = self.urlRequest(for: createReq)
        
        // make a task on the current URLSession
        let authURLSession = URLSession.shared
        let task = authURLSession.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            self?.queue.async { [weak self] in
                
                let dataResult = CoreAPI.parseAPIResponse(data: data, response: response, error: error)
                let sessionResult: Result<AuthSession> = CoreAPI.parseDataResult(dataResult)
                
                switch sessionResult {
                case .success(let authSession):
                    self?.authState = .authorized(session: authSession)
                    
                    // on success, perform all the pending requestOps
                    let allRequests = self?.activeRequests
                    allRequests?.forEach({ (token, reqOp) in
                        self?.attemptToStart(requestOp: reqOp)
                    })
                    
                case .error(let err):
                    // TODO: what happens when auth fails (network?). Retry.
                    print("crap, auth error", err)
                    break;
                }
            }
        }
        
        task.resume()
    }

    private func retry(requestOp: RequestOperation, after delay: TimeInterval) {
        ShopGunSDK.log("Will Retry Request (after: \(delay)) \(requestOp.request.path)", level: .debug, source: .CoreAPI)

        // make a new requestOp with an increased retryCount and a cleared task
        var newRequestOp = requestOp
        newRequestOp.retryCount += 1
        newRequestOp.task = nil
        activeRequests[requestOp.token] = newRequestOp
        
        // once the retry time is up, perform the request again
        self.queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.attemptToStart(requestOp: newRequestOp)
        }
    }
    
    private func finish(requestOp: RequestOperation, result: Result<Data>) {
        ShopGunSDK.log("Request Finalized \(requestOp.request.path): \(result)", level: .debug, source: .CoreAPI)
        
        // remove from the pending queue
        activeRequests[requestOp.token] = nil
        
        // pass the result to the requestOp
        // final completion always called on main
        DispatchQueue.main.async {
            requestOp.completion?(result)
        }
    }
    
    // what to do when a requestOp finishes
    private func handleRequestOpCompletion(requestOp: RequestOperation, result: Result<Data>) {
        ShopGunSDK.log("Request Completed \(requestOp.request.path): \(result)", level: .debug, source: .CoreAPI)
        
        switch result {
        case .error(let err as CoreAPIError)
            where err.isRetryable && requestOp.retryCount < requestOp.request.maxRetryCount:
            // The error is retryable (and hasnt been retried too many times) ... so retry it
            
            retry(requestOp: requestOp, after: (err.canRetryAfter ?? 0.0))
            
        case .error(let err as CoreAPIError)
            where err.requiresRenewedAuthSession && failedAuthRenewCount < 3 && requestOp.retryCount < requestOp.request.maxRetryCount:
            // It is an auth-error that requires the session to be renewed/recreated
            
            // increase the requestOp's retryCount, to avoid repeatedly spamming this request if it keeps failing
            var newRequestOp = requestOp
            newRequestOp.retryCount += 1
            newRequestOp.task = nil
            activeRequests[requestOp.token] = newRequestOp
            
            renewAuthSession()
        case .success(_),
             .error(_):
            // a success, or a non-specific, non-retryable error
            // ... perform the requestOp's completion handler
            finish(requestOp: requestOp, result: result)
        }
    }
    
    // Takes a RequestOperation and tries to perform it
    // (given the current state of the URLSession/settings
    private func attemptToStart(requestOp: RequestOperation) {
        
        ShopGunSDK.log("Attempting to start \(requestOp.request.path)", level: .debug, source: .CoreAPI)
        
        // check the state of the auth session
        switch self.authState {
        case .authorized(_):
            // perform the request with the current auth session
            start(requestOp: requestOp)
        case .authorizing:
            // we are currently in the processes of authorizing the urlSession.
            // do nothing until that completes
            break;
        case .unauthorized:
            // if the request doesnt require auth, perform it.
            if requestOp.request.requiresAuth == false {
                start(requestOp: requestOp)
            }

            // either way, start renewing the authSession by entering the 'authorizing' state
            self.renewAuthSession()
        }
    }
    
    private func urlRequest(for request: CoreAPIRequest) -> URLRequest {
        let appVersion = settings.appVersion
        let locale = settings.locale
        let baseURL = settings.baseURL
        
        let urlReq = request.urlRequest(for: baseURL,
                                        additionalParameters: ["api_av": appVersion,
                                                               "r_locale": locale])
        return urlReq
    }
    
    private func start(requestOp: RequestOperation) {
        
        ShopGunSDK.log("Starting \(requestOp.request.path)", level: .debug, source: .CoreAPI)
        
        let urlRequest = self.urlRequest(for: requestOp.request)
        
        // make a task on the current URLSession
        let task = urlSession.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            let result = CoreAPI.parseAPIResponse(data: data, response: response, error: error)
            
            self?.queue.async {
                self?.handleRequestOpCompletion(requestOp: requestOp, result: result)
            }
        }
        
        // save that task on the requestOp
        var newRequestOp = requestOp
        newRequestOp.task = task
        activeRequests[requestOp.token] = newRequestOp
        
        // start the task
        task.resume()
    }
}

extension CoreAPI.Settings {
    public static func `default`(key: String, secret: String, locale: String, appVersion: String) -> CoreAPI.Settings {
        return .init(key: key, secret: secret, baseURL: URL(string: "https://api.etilbudsavis.dk")!, locale: locale, appVersion: appVersion)
    }
}

extension CoreAPI {
    // Simple namespace for keeping Requests
    public struct Requests { private init() {} }
}

// MARK: -

/// This represents the state of an 'active' request being handled by the CoreAPI
fileprivate struct RequestOperation {
    
    var request: CoreAPIRequest
    var token: RequestToken
    var retryCount: Int
    var completion: ((Result<Data>) -> ())?
    var task: URLSessionTask?
    
    init(request: CoreAPIRequest, token: RequestToken, retryCount: Int = 0, completion: ((Result<Data>) -> ())?) {
        self.request = request
        self.token = token
        self.retryCount = retryCount
        self.completion = completion
    }
}

fileprivate struct RequestToken: Cancellable, Hashable {
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
fileprivate func == (lhs: RequestToken, rhs: RequestToken) -> Bool {
    return lhs.id == rhs.id
}

// Internal requests
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
