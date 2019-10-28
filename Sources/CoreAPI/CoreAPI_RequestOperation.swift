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
        typealias CompletionHandler = ((Result<Data, Error>) -> Void)
        
        let id: Identifier
        
        private var requiresAuth: Bool
        private var remainingRetries: Int
        private let originalURLRequest: URLRequest
        private let completion: CompletionHandler?
        private let urlSession: URLSession
        
        private var activeTask: URLSessionTask?
        private var remainingRegenerateAuthRetries: Int = 3
        private var queue: DispatchQueue = DispatchQueue(label: "ShopGunSDK.CoreAPI.RequestOperationQ")

        init(id: Identifier = .generate(), requiresAuth: Bool, maxRetryCount: Int, urlRequest: URLRequest, urlSession: URLSession, completion: CompletionHandler?) {
            self.id = id
            self.requiresAuth = requiresAuth
            self.remainingRetries = maxRetryCount
            self.originalURLRequest = urlRequest
            self.completion = completion
            
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
                self?.completion?(.failure(APIError.requestCancelled))
                
                self?.activeTask?.cancel()
                
                self?.state = .finished
            }
        }
        
        private func startPerformingRequest() {
            self.performRequest(self.originalURLRequest)
        }
        
        private func performRequest(_ urlRequest: URLRequest) {
            let task = self.urlSession.coreAPIDataTask(with: urlRequest) { [weak self] (dataResult: Result<Data, Error>) in
                guard self?.isCancelled == false else { return }

                self?.queue.async { [weak self] in
                    self?.requestCompleted(withResult: dataResult)
                }
            }
            self.activeTask? = task
            task.resume()
        }
        
        private func requestCompleted(withResult result: Result<Data, Error>) {
            switch result {
            case .success:
                self.finish(withResult: result)
            case .failure(let error as CoreAPI.APIError)
                where error.isRetryable && self.remainingRetries > 0:
                // The error is retryable (and hasnt been retried too many times) ... so retry it
                self.remainingRetries -= 1
                
                self.queue.asyncAfter(deadline: .now() + (error.canRetryAfter ?? 0.0)) { [weak self] in
                    self?.startPerformingRequest()
                }
            case .failure:
                // All other possible errors (or we have retried too many times)
                self.finish(withResult: result)
            }
        }
        
        private func finish(withResult result: Result<Data, Error>) {
            self.completion?(result)
            self.state = .finished
        }
    }
}
