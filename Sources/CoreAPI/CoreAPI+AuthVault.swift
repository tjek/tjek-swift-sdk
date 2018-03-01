//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import CommonCrypto

extension CoreAPI {
    
    final class AuthVault {
        // MARK: - Types
        
        enum AuthRegenerationType {
            case create // destroy and recreate a new token
            case renewOrCreate // just renew the current token's expiry (performs `create` if no token)
            case reauthorize(LoginCredentials) // renew the current token the specified credentials (fails if no token)
        }
        
        typealias SignedRequestCompletion = ((Result<URLRequest>) -> Void)
        
        // MARK: Funcs
        
        init(baseURL: URL, key: String, secret: String, tokenLife: Int = 7_776_000, urlSession: URLSession, secureDataStore: ShopGunSDKSecureDataStore?) {
            self.baseURL = baseURL
            self.key = key
            self.secret = secret
            self.tokenLife = tokenLife
            self.secureDataStore = secureDataStore
            
            self.urlSession = urlSession
            
            self.activeRegenerateTask = nil
 
            // load clientId/authState from the store (if provided)
            let storedAuth = AuthVault.loadFromDataStore(secureDataStore)
            if let auth = storedAuth.auth {
                // Apply stored auth if it exists
                self.authState = .authorized(token: auth.token, user: auth.user, clientId: storedAuth.clientId)
            } else if let legacyAuthState = AuthVault.loadLegacyAuthState() {
                // load, apply & clear any legacy auth from the previous version of the SDK
                self.authState = legacyAuthState
                self.updateStore()
                AuthVault.clearLegacyAuthState()
                ShopGun.log("Loaded AuthState from Legacy cache", level: .debug, source: .CoreAPI)
            } else {
                // If no stored auth, or legacy auth to migrate, mark as unauthorized.
                self.authState = .unauthorized(error: nil, clientId: storedAuth.clientId)
            }
        }

        func regenerate(_ type: AuthRegenerationType, completion: ((Error?) -> Void)? = nil) {
            self.queue.async { [weak self] in
                self?.regenerateOnQueue(type, completion: completion)
            }
        }
        
        // Returns a new urlRequest that has been signed with the authToken
        // If we are not authorized, or in the process of authorizing, then this can take some time to complete.
        func signURLRequest(_ urlRequest: URLRequest, completion: @escaping SignedRequestCompletion) {
            self.queue.async { [weak self] in
                self?.signURLRequestOnQueue(urlRequest, completion: completion)
            }
        }
        
        var authorizedUserDidChangeCallback: ((_ prev: AuthorizedUser?, _ new: AuthorizedUser?) -> Void)?
        var additionalRequestParams: [String: String] = [:]
    
        /// If we are authorized, and have an authorized user, then this is non-nil
        var currentAuthorizedUser: AuthorizedUser? {
            if case .authorized(_, let user, _) = self.authState, user != nil {
                return user
            } else {
                return nil
            }
        }
        
        func resetStoredAuthState() {
            self.queue.async { [weak self] in
                guard let s = self else { return }
                
                AuthVault.updateDataStore(s.secureDataStore, data: nil)
                s.authState = .unauthorized(error: nil, clientId: nil)
            }
        }
        
        // MARK: - Private Types
        
        enum AuthState {
            case unauthorized(error: Error?, clientId: ClientIdentifier?) // we currently have no auth (TODO: `reason` enum insted of error?)
            case authorized(token: String, user: AuthorizedUser?, clientId: ClientIdentifier?) // we have signed headers to return
        }
        
        // MARK: Private Vars
        
        private let baseURL: URL
        private let key: String
        private let secret: String
        private let tokenLife: Int
        private weak var secureDataStore: ShopGunSDKSecureDataStore?
        private let urlSession: URLSession
        private let queue = DispatchQueue(label: "ShopGunSDK.CoreAPI.AuthVault.Queue")
        // if we are in the process of regenerating the token, this is set
        private var activeRegenerateTask: (type: AuthRegenerationType, task: URLSessionTask)?
        
        private var pendingSignedRequests: [(URLRequest, SignedRequestCompletion)] = []
        
        private var authState: AuthState {
            didSet {
                // save the current authState to the store
                updateStore()
                
                // TODO: change to 'authStateDidChange', and trigger for _any_ change to the authState
                guard let authDidChangeCallback = self.authorizedUserDidChangeCallback else { return }
                
                var prevAuthUser: AuthorizedUser? = nil
                if case .authorized(_, let user?, _) = oldValue {
                    prevAuthUser = user
                }
                if prevAuthUser?.person != currentAuthorizedUser?.person || prevAuthUser?.provider != currentAuthorizedUser?.provider {
                    authDidChangeCallback(prevAuthUser, currentAuthorizedUser)
                }
            }
        }
        
        var clientId: ClientIdentifier? {
            switch self.authState {
            case .authorized(_, _, let clientId),
                 .unauthorized(_, let clientId):
                return clientId
            }
        }
        
        // MARK: Funcs
        
        private func regenerateOnQueue(_ type: AuthRegenerationType, completion: ((Error?) -> Void)? = nil) {
            
            // If we are in the process of doing a different kind of regen, cancel it
            cancelActiveRegenerateTask()
            
            var mutableCompletion = completion
            
            // generate a request based on the regenerate type
            let request: CoreAPI.Request<AuthSessionResponse>
            switch (type, self.authState) {
            case (.create, _),
                 (.renewOrCreate, .unauthorized):
                request = AuthSessionResponse.createRequest(clientId: self.clientId, apiKey: self.key, tokenLife: self.tokenLife)
            case (.renewOrCreate, .authorized):
                request = AuthSessionResponse.renewRequest(clientId: self.clientId)
            case (.reauthorize(let credentials), .authorized):
                request = AuthSessionResponse.renewRequest(clientId: self.clientId, additionalParams: credentials.requestParams)
            case (.reauthorize, .unauthorized):
                
                // if we have no valid token at all when trying to reauthorize then just create
                request = AuthSessionResponse.createRequest(clientId: self.clientId, apiKey: self.key, tokenLife: self.tokenLife)
                
                // once completed, if we are authorized, then reauthorize with the credentials
                mutableCompletion = { [weak self] (createError) in
                    self?.queue.async { [weak self] in
                        guard case .authorized? = self?.authState else {
                            DispatchQueue.main.async {
                                completion?(createError)
                            }
                            return
                        }
                        self?.regenerate(type, completion: completion)
                    }
                }
            }
            
            var urlRequest = request.urlRequest(for: self.baseURL, additionalParameters: self.additionalRequestParams)
            if case .authorized(let token, _, _) = self.authState {
                urlRequest = urlRequest.signedForCoreAPI(withToken: token, secret: self.secret)
            }
            
            let task = self.urlSession.coreAPIDataTask(with: urlRequest) { [weak self] (authSessionResult: Result<AuthSessionResponse>) -> Void in
                self?.queue.async { [weak self] in
                    self?.activeRegenerateTaskCompleted(authSessionResult)
                    DispatchQueue.main.async {
                        mutableCompletion?(authSessionResult.error)
                    }
                }
            }
            
            self.activeRegenerateTask = (type: type, task: task)
            task.resume()
        }
        
        private func signURLRequestOnQueue(_ urlRequest: URLRequest, completion: @escaping SignedRequestCompletion) {
            
            // check if we are in the process of regenerating the token
            // if so just save the completion handler to be run once regeneration finishes
            guard self.activeRegenerateTask == nil else {
                self.pendingSignedRequests.append((urlRequest, completion))
                return
            }
            
            switch self.authState {
            case .unauthorized(let authError, _):
                if let authError = authError {
                    // unauthorized, with an error, so perform completion and forward the error
                    DispatchQueue.main.async {
                        completion(.error(authError))
                    }
                } else {
                    // unauthorized, without an error, so cache completion & start regenerating token
                    self.pendingSignedRequests.append((urlRequest, completion))
                    self.regenerate(.renewOrCreate)
                }
            case let .authorized(token, _, _):
                // we are authorized, so sign the request and perform the completion handler
                let signedRequest = urlRequest.signedForCoreAPI(withToken: token, secret: self.secret)
                DispatchQueue.main.async {
                    completion(.success(signedRequest))
                }
            }
        }
        
        /// Save the current AuthState to the store
        private func updateStore() {
            guard let store = self.secureDataStore else { return }
            
            switch self.authState {
            case .unauthorized(_, nil):
                AuthVault.updateDataStore(store, data: nil)
            case let .unauthorized(_, clientId):
                AuthVault.updateDataStore(store, data: StoreData(auth: nil, clientId: clientId))
            case let .authorized(token, user, clientId):
                AuthVault.updateDataStore(store, data: StoreData(auth: (token: token, user: user), clientId: clientId))
            }
        }
        
        // If we are in the process of doing a different kind of regen, cancel it
        private func cancelActiveRegenerateTask() {
            self.activeRegenerateTask?.task.cancel()
            self.activeRegenerateTask = nil
        }
        
        private func activeRegenerateTaskCompleted(_ result: Result<AuthSessionResponse>) {
            
            switch result {
            case .success(let authSession):
                ShopGun.log("successfully updated authSession \(authSession)", level: .debug, source: .CoreAPI)
                
                self.authState = .authorized(token: authSession.token, user: authSession.authorizedUser, clientId: authSession.clientId)
                self.activeRegenerateTask = nil
                
                // we are authorized, so sign the requests and perform the completion handlers
                for (urlRequest, completion) in self.pendingSignedRequests {
                    let signedRequest = urlRequest.signedForCoreAPI(withToken: authSession.token, secret: self.secret)
                    DispatchQueue.main.async {
                        completion(.success(signedRequest))
                    }
                }
                
            case .error(let cancelError as NSError)
                where cancelError.domain == NSURLErrorDomain && cancelError.code == URLError.Code.cancelled.rawValue:
                // if cancelled then ignore
                break
            case .error(let regenError):
                ShopGun.log("Failed to update authSession \(regenError)", level: .error, source: .CoreAPI)
                
                // TODO: depending upon the error do different things
                // - what if retryable? network error?
                for (_, completion) in self.pendingSignedRequests {
                    DispatchQueue.main.async {
                        completion(.error(regenError))
                    }
                }
            }
        }
    }
}

// MARK: -

extension CoreAPI.AuthVault {
    
    /// The response from requests to the API's session endpoint
    fileprivate struct AuthSessionResponse: Decodable {
        var clientId: CoreAPI.ClientIdentifier
        var token: String
        var expiry: Date
        var authorizedUser: CoreAPI.AuthorizedUser?
        
        enum CodingKeys: String, CodingKey {
            case clientId   = "client_id"
            case token      = "token"
            case expiry     = "expires"
            case provider   = "provider"
            case person     = "user"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.clientId = try values.decode(CoreAPI.ClientIdentifier.self, forKey: .clientId)
            self.token = try values.decode(String.self, forKey: .token)
            
            if let provider = try? values.decode(CoreAPI.AuthorizedUserProvider.self, forKey: .provider),
                let person = try? values.decode(CoreAPI.Person.self, forKey: .person) {
                self.authorizedUser = (person, provider)
            }
            
            let expiryString = try values.decode(String.self, forKey: .expiry)
            if let expiryDate = CoreAPI.dateFormatter.date(from: expiryString) {
                self.expiry = expiryDate
            } else {
                throw DecodingError.dataCorruptedError(forKey: .expiry, in: values, debugDescription: "Date string does not match format expected by formatter (\(CoreAPI.dateFormatter.dateFormat)).")
            }
        }
        
        // MARK: Response-generating requests
        
        static func createRequest(clientId: CoreAPI.ClientIdentifier?, apiKey: String, tokenLife: Int) -> CoreAPI.Request<AuthSessionResponse> {
            
            var params: [String: String] = [:]
            params["api_key"] = apiKey
            params["token_ttl"] = String(tokenLife)
            params["clientId"] = clientId?.rawValue
            
            return .init(path: "v2/sessions", method: .POST, requiresAuth: false, parameters: params, timeoutInterval: 10)
        }
        
        static func renewRequest(clientId: CoreAPI.ClientIdentifier?, additionalParams: [String: String] = [:]) -> CoreAPI.Request<AuthSessionResponse> {
            
            var params: [String: String] = additionalParams
            params["clientId"] = clientId?.rawValue
            
            return .init(path: "v2/sessions", method: .PUT, requiresAuth: true, parameters: params, timeoutInterval: 10)
        }
    }
}

// MARK: - DataStore

extension CoreAPI.AuthVault {
    
    fileprivate static let dataStoreKey = "ShopGunSDK.CoreAPI.AuthVault"
    
    fileprivate static func updateDataStore(_ dataStore: ShopGunSDKSecureDataStore?, data: CoreAPI.AuthVault.StoreData?) {
        var authJSON: String? = nil
        if let data = data,
            let authJSONData = try? JSONEncoder().encode(data) {
            authJSON = String(data: authJSONData, encoding: .utf8)
        }
        dataStore?.set(value: authJSON, for: CoreAPI.AuthVault.dataStoreKey)
    }
    
    fileprivate static func loadFromDataStore(_ dataStore: ShopGunSDKSecureDataStore?) -> CoreAPI.AuthVault.StoreData {
        guard let authJSONData = dataStore?.get(for: CoreAPI.AuthVault.dataStoreKey)?.data(using: .utf8),
            let auth = try? JSONDecoder().decode(CoreAPI.AuthVault.StoreData.self, from: authJSONData) else {
                return .init(auth: nil, clientId: nil)
        }
        return auth
    }
    
    // The data to be saved/read from disk
    fileprivate struct StoreData: Codable {
        var auth: (token: String, user: CoreAPI.AuthorizedUser?)?
        var clientId: CoreAPI.ClientIdentifier?
        
        init(auth: (token: String, user: CoreAPI.AuthorizedUser?)?, clientId: CoreAPI.ClientIdentifier?) {
            self.auth = auth
            self.clientId = clientId
        }
        
        enum CodingKeys: String, CodingKey {
            case authToken  = "auth.token"
            case authUserPerson = "auth.user.person"
            case authUserProvider = "auth.user.provider"
            case clientId  = "clientId"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            if let token = try? values.decode(String.self, forKey: .authToken) {
                let authorizedUser: CoreAPI.AuthorizedUser?
                if let provider = try? values.decode(CoreAPI.AuthorizedUserProvider.self, forKey: .authUserProvider),
                    let person = try? values.decode(CoreAPI.Person.self, forKey: .authUserPerson) {
                    authorizedUser = (person, provider)
                } else {
                    authorizedUser = nil
                }
                
                self.auth = (token: token, user: authorizedUser)
            } else {
                self.auth = nil
            }
            
            self.clientId = try? values.decode(CoreAPI.ClientIdentifier.self, forKey: .clientId)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try? container.encode(self.auth?.token, forKey: .authToken)
            try? container.encode(self.auth?.user?.person, forKey: .authUserPerson)
            try? container.encode(self.auth?.user?.provider, forKey: .authUserProvider)
            
            try? container.encode(self.clientId, forKey: .clientId)
        }
    }
}

// MARK: -

extension URLRequest {
    
    /// Generates a new URLRequest that includes the signed HTTPHeaders, given a token & secret
    fileprivate func signedForCoreAPI(withToken token: String, secret: String) -> URLRequest {
        // make an SHA256 Hex string
        let hashString: String?
        if let data = (secret + token).data(using: .utf8) {
            hashString = data.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> String in
                var hash: [UInt8] = .init(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                _ = CC_SHA256(bytes, CC_LONG(data.count), &hash)
                
                return hash.reduce("", { $0 + String(format: "%02x", $1) })
            })
        } else {
            hashString = nil
        }
        
        var signedRequest = self
        signedRequest.setValue(token, forHTTPHeaderField: "X-Token")
        signedRequest.setValue(hashString, forHTTPHeaderField: "X-Signature")
        return signedRequest
    }
}

// MARK: -

extension CoreAPI.LoginCredentials {
    
    /// What are the request params that a specific loginCredential needs to send when reauthorizing
    fileprivate var requestParams: [String: String] {
        switch self {
        case .logout:
            return ["email": ""]
        case let .shopgun(email, password):
            return ["email": email,
                    "password": password]
        case let .facebook(token):
            return ["facebook_token": token]
        }
    }
}

// MARK: -

extension CoreAPI.AuthVault.AuthRegenerationType: Equatable {
    static func == (lhs: CoreAPI.AuthVault.AuthRegenerationType, rhs: CoreAPI.AuthVault.AuthRegenerationType) -> Bool {
        switch (lhs, rhs) {
        case (.create, .create): return true
        case (.renewOrCreate, .renewOrCreate): return true
        case (.reauthorize(let lhsCred), .reauthorize(let rhsCred)):
            return lhsCred == rhsCred
            
        case (.create, _),
             (.renewOrCreate, _),
             (.reauthorize(_), _):
            return false
        }
    }
}
