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

// How to read/save the state to disk
protocol CoreAPIAuthVaultStore {
    func updateAuth(_ auth: (token: String, user: CoreAPI.AuthorizedUser?)?, clientId: CoreAPI.AuthVault.ClientIdentifier?)
    func loadAuth() -> (auth: (token: String, user: CoreAPI.AuthorizedUser?)?, clientId: CoreAPI.AuthVault.ClientIdentifier?)
}

extension CoreAPI {
    
    final class AuthVault {
        
        // MARK: - Types
        
        enum AuthRegenerationType {
            case create // destroy and recreate a new token
            case renewOrCreate // just renew the current token's expiry (performs `create` if no token)
            case reauthorize(LoginCredentials) // renew the current token the specified credentials (fails if no token)
        }
        
        typealias SignedRequestCompletion = ((Result<URLRequest>) -> Void)
        
        enum ClientIdentifierType {}
        typealias ClientIdentifier = GenericIdentifier<ClientIdentifierType>

        // MARK: Funcs
        
        // TODO: Need additional locale/version properties that need to be passed in. And userAgent. Maybe just accept a pre-configured URLSession param
        // TODO: notify of user changes somehow
        init(baseURL: URL, key: String, secret: String, tokenLife: Int = 7_776_000, store: CoreAPIAuthVaultStore?) {
            self.baseURL = baseURL
            self.key = key
            self.secret = secret
            self.tokenLife = tokenLife
            self.store = store
            
            let sessionConfig = URLSessionConfiguration.default
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.activeRegenerateTask = nil
            
            // load clientId/authState from the store (if provided)
            let storedAuth = store?.loadAuth()

            if let auth = storedAuth?.auth {
                self.authState = .authorized(token: auth.token, user: auth.user, clientId: storedAuth?.clientId)
            } else {
                self.authState = .unauthorized(error: nil, clientId: storedAuth?.clientId)
            }
        }

        func regenerate(_ type: AuthRegenerationType) {
            // check that we are not currently doing exactly the same kind of regen.. if so: eject
            guard self.activeRegenerateTask?.type != type else {
                return
            }
            
            // If we are in the process of doing a different kind of regen, cancel it
            cancelActiveRegenerateTask()
            
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
                // TODO: maybe do something where we authorize on completion?
                request = AuthSessionResponse.createRequest(clientId: self.clientId, apiKey: self.key, tokenLife: self.tokenLife)
            }
            
            var urlRequest = request.urlRequest(for: self.baseURL, additionalParameters: [:])
            if case .authorized(let token, _, _) = self.authState {
                urlRequest = urlRequest.signedForCoreAPI(withToken: token, secret: self.secret)
            }
            
            let task = self.urlSession.coreAPIDataTask(with: urlRequest) { [weak self] (authSessionResult: Result<AuthSessionResponse>) -> Void in
                // TODO: jump back to shared queue
                self?.activeRegenerateTaskCompleted(authSessionResult)
            }
            
            self.activeRegenerateTask = (type: type, task: task)
            task.resume()
        }
        
        // Get the httpHeaders to include in future requests that require auth.
        // The completion will only be called once renew completes
        // If this is called multiple times while renewing, all the completions will be called at once.
        // If we have no auth when this is called it will trigger `updateAuth`
        func signURLRequest(_ urlRequest: URLRequest, completion: @escaping SignedRequestCompletion) {

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
                    completion(.error(authError))
                } else {
                    // unauthorized, without an error, so cache completion & start regenerating token
                    self.pendingSignedRequests.append((urlRequest, completion))
                    self.regenerate(.renewOrCreate)
                }
            case let .authorized(token, _, _):
                
                // we are authorized, so sign the request and perform the completion handler
                let signedRequest = urlRequest.signedForCoreAPI(withToken: token, secret: self.secret)
                completion(.success(signedRequest))
            }
        }
        
        /// If we are authorized, and have an authorized user, then this is non-nil
        var currentAuthorizedUser: AuthorizedUser? {
            if case .authorized(_, let user, _) = self.authState {
                return user
            } else {
                return nil
            }
        }
        
        // MARK: - Private Types
        
        private enum AuthState {
            case unauthorized(error: Error?, clientId: ClientIdentifier?) // we currently have no auth (TODO: `reason` enum insted of error?)
            case authorized(token: String, user: AuthorizedUser?, clientId: ClientIdentifier?) // we have signed headers to return
        }
        
        // MARK: Private Vars
        
        private let baseURL: URL
        private let key: String
        private let secret: String
        private let tokenLife: Int
        private let store: CoreAPIAuthVaultStore?
        private let urlSession: URLSession

        // if we are in the process of regenerating the token, this is set
        private var activeRegenerateTask: (type: AuthRegenerationType, task: URLSessionTask)?
        
        private var authState: AuthState {
            didSet {
                // save the current authState to the store
                updateStore()
            }
        }
        
        private var clientId: ClientIdentifier? {
            switch self.authState {
            case .authorized(_, _, let clientId),
                 .unauthorized(_, let clientId):
                return clientId
            }
        }
        
        private var pendingSignedRequests: [(URLRequest, SignedRequestCompletion)] = []
        
        // MARK: Funcs
        
        /// Save the current AuthState to the store
        private func updateStore() {
            switch self.authState {
            case let .unauthorized(_, clientId):
                self.store?.updateAuth(nil, clientId: clientId)
            case let .authorized(token, user, clientId):
                self.store?.updateAuth((token: token, user: user), clientId: clientId)
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
                ShopGunSDK.log("successfully updated authSession \(authSession)", level: .debug, source: .CoreAPI)
                
                self.authState = .authorized(token: authSession.token, user: authSession.authorizedUser, clientId: authSession.clientId)
                self.activeRegenerateTask = nil
                
                // we are authorized, so sign the requests and perform the completion handlers
                for (urlRequest, completion) in self.pendingSignedRequests {
                    let signedRequest = urlRequest.signedForCoreAPI(withToken: authSession.token, secret: self.secret)
                    completion(.success(signedRequest))
                }
                
            case .error(let cancelError as NSError)
                where cancelError.domain == NSURLErrorDomain && cancelError.code == URLError.Code.cancelled.rawValue:
                // if cancelled then ignore
                break;
            case .error(let regenError):
                ShopGunSDK.log("failed to update authSession \(regenError)", level: .error, source: .CoreAPI)
                
                // TODO: depending upon the error do different things
                // - what if retryable? network error?
                for (_, completion) in self.pendingSignedRequests {
                    completion(.error(regenError))
                }
            }
        }
        
        // MARK: -
        
        /// The response from requests to the API's session endpoint
        fileprivate struct AuthSessionResponse: Decodable {
            var clientId: ClientIdentifier
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
                
                self.clientId = try values.decode(ClientIdentifier.self, forKey: .clientId)
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
            
            static func createRequest(clientId: CoreAPI.AuthVault.ClientIdentifier?, apiKey: String, tokenLife: Int) -> CoreAPI.Request<AuthSessionResponse> {
                
                var params: [String: String] = [:]
                params["api_key"] = apiKey
                params["token_ttl"] = String(tokenLife)
                params["clientId"] = clientId?.rawValue
                
                return .init(path: "v2/sessions", method: .POST, requiresAuth: false, parameters: params, timeoutInterval: 10)
            }
            
            static func renewRequest(clientId: CoreAPI.AuthVault.ClientIdentifier?, additionalParams: [String: String] = [:]) -> CoreAPI.Request<AuthSessionResponse> {
                
                var params: [String: String] = additionalParams
                params["clientId"] = clientId?.rawValue
                
                return .init(path: "v2/sessions", method: .PUT, requiresAuth: true, parameters: params, timeoutInterval: 10)
            }
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
        switch self{
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

extension CoreAPI.AuthVault.AuthRegenerationType: Equatable { }
func == (lhs: CoreAPI.AuthVault.AuthRegenerationType, rhs: CoreAPI.AuthVault.AuthRegenerationType) -> Bool {
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
