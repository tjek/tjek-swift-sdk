//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension CoreAPI {
    
    /// This represents the state of an 'active' request being handled by the CoreAPI
    class RequestOperation: AsyncOperation {
        typealias Identifier = GenericIdentifier<RequestOperation>
        let id: Identifier
        
        private var requiresAuth: Bool
        private var remainingRetries: Int
        private let originalURLRequest: URLRequest
        private let completion: ((Result<Data>) -> ())?
        private let authVault: AuthVault?
        private let urlSession: URLSession
        
        private var activeTask: URLSessionTask?
        private var remainingRegenerateAuthRetries: Int = 3
        private var queue: DispatchQueue = DispatchQueue(label: "ShopGunSDK.CoreAPI.RequestOperationQ")

        init(id: Identifier = .generate(), requiresAuth: Bool,  maxRetryCount: Int, urlRequest: URLRequest, authVault: AuthVault?, urlSession: URLSession, completion: ((Result<Data>) -> ())?) {
            self.id = id
            self.requiresAuth = requiresAuth
            self.remainingRetries = maxRetryCount
            self.originalURLRequest = urlRequest
            self.completion = completion
            
            self.authVault = authVault
            self.urlSession = urlSession
            
            self.activeTask = nil
        }
        
        override func main() {
            super.main()
            
            self.queue.async { [weak self] in
                self?.startPerformingRequest()
            }
        }
        
        override func cancel() {
            super.cancel()
            
            self.queue.async { [weak self] in
                self?.completion?(.error(APIError.requestCancelled))
                
                self?.activeTask?.cancel()
                
                self?.state = .finished
            }
        }
        
        private func startPerformingRequest() {
            guard requiresAuth, let authVault = self.authVault else {
                // no auth required, just perform with the original, unsigned, urlRequest
                self.performRequest(self.originalURLRequest)
                return
            }
            
            authVault.signURLRequest(self.originalURLRequest) { [weak self] (authResult) in
                guard self?.isCancelled == false else { return }
                
                self?.queue.async { [weak self] in
                    switch authResult {
                    case .success(let signedURLRequest):
                        self?.performRequest(signedURLRequest)
                    case .error(let authError):
                        self?.finish(withResult: .error(authError))
                    }
                }
            }
        }
        
        private func performRequest(_ urlRequest: URLRequest) {
            let task = self.urlSession.coreAPIDataTask(with: urlRequest) { [weak self] (dataResult: Result<Data>) in
                guard self?.isCancelled == false else { return }

                self?.queue.async { [weak self] in
                    self?.requestCompleted(withResult: dataResult)
                }
            }
            self.activeTask? = task
            task.resume()
        }
        
        private func requestCompleted(withResult result: Result<Data>) {
            switch result {
            case .success:
                self.finish(withResult: result)
            case .error(let error as CoreAPI.APIError)
                where error.isRetryable && self.remainingRetries > 0:
                // The error is retryable (and hasnt been retried too many times) ... so retry it
                self.remainingRetries -= 1
                
                self.queue.asyncAfter(deadline: .now() + (error.canRetryAfter ?? 0.0)) { [weak self] in
                    self?.startPerformingRequest()
                }
            case .error(let error as CoreAPI.APIError)
                where error.requiresRenewedAuthSession && self.remainingRegenerateAuthRetries > 0 && self.authVault != nil:
                // It was an auth error (and we havnt run out of retries)
                // Trigger a regenerate on the vault, and retry
                
                self.authVault?.regenerate(.renewOrCreate)
                
                self.activeTask = nil
                self.requiresAuth = true
                self.remainingRegenerateAuthRetries -= 1
                
                self.startPerformingRequest()
            case .error:
                // All other possible errors (or we have retried too many times)
                self.finish(withResult: result)
            }
        }
        
        private func finish(withResult result: Result<Data>) {
            self.completion?(result)
            self.state = .finished
        }
    }
}
