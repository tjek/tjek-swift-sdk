///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation

public class APIClient {
    
    // MARK: - Public vars
    
    public typealias ResponseListener = (queue: DispatchQueue, callback: (_ endpointName: String, Result<HTTPURLResponse, APIError>) -> Void)
    
    public var baseURL: URL
    public let defaultEncoder: JSONEncoder
    public let defaultDecoder: JSONDecoder
    
    // MARK: - Private vars
    
    private var clientHeaders: [String: String?]
    private var responseListeners: [ResponseListener] = []
    private let urlSession: URLSession
    private let requestQueue: DispatchQueue = DispatchQueue(label: "APIClient Queue")
    
    // MARK: - Public funcs
    
    public init(
        baseURL: URL,
        urlSession: URLSession = URLSession(configuration: .default),
        headers: [String: String?] = [:],
        defaultEncoder: JSONEncoder = JSONEncoder(),
        defaultDecoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.clientHeaders = headers
        self.defaultEncoder = defaultEncoder
        self.defaultDecoder = defaultDecoder
    }
    
    /// The response listener callback will be called on the specified queue whenever a request completes. It receives the url response or the error.
    public func addResponseListener(on queue: DispatchQueue, _ callback: @escaping (_ endpointName: String, Result<HTTPURLResponse, APIError>) -> Void) {
        self.responseListeners.append((
            queue: queue,
            callback: callback
        ))
    }
    
    // MARK: - Private funcs
    
    private func callResponseListeners(endpointName: String, result: Result<HTTPURLResponse, APIError>) {
        self.responseListeners.forEach({ listener in
            listener.queue.async {
                listener.callback(endpointName, result)
            }
        })
    }
}

// MARK: - Common request headers

/// A typealias for the token type used to sign v2 & v4 requests.
public typealias AuthToken = String

extension APIClient {
    
    public func setAuthToken(_ authToken: AuthToken?) {
        self.clientHeaders["X-Token"] = authToken
    }
    
    /// All future requests will use the specified APIKey/secret.
    public func setAPIKey(_ apiKey: String, apiSecret: String) {
        self.clientHeaders["X-Api-Key"] = apiKey
        self.clientHeaders["X-Api-Secret"] = apiSecret
    }
    
    /// All future requests will use the specified app version (in simVer).
    public func setClientVersion(_ appVersion: String) {
        self.clientHeaders["X-Client-Version"] = appVersion
    }
}

// MARK: - Send

extension APIClient {
    
    /**
     Send a request to the API's urlSession.
     Will report the HTTPURLResponse or API error to the `responseListeners`.
     Calls the completionHandler async on the `completesOn` queue.
     */
    public func send<ResponseType, VersionTag>(
        _ request: APIRequest<ResponseType, VersionTag>,
        completesOn completionQueue: DispatchQueue = .main,
        completion: @escaping (Result<ResponseType, APIError>) -> Void
    ) {
        self.requestQueue.async { [weak self] in
            self?.queuedSend(request, completesOn: completionQueue, completion: completion)
        }
    }
    
    /// Actually does the sending of the request. This must be run on the `requestQueue`
    fileprivate func queuedSend<ResponseType, VersionTag>(
        _ request: APIRequest<ResponseType, VersionTag>,
        completesOn completionQueue: DispatchQueue,
        completion: @escaping (Result<ResponseType, APIError>) -> Void
    ) {
        let handleResult: (Result<(ResponseType, HTTPURLResponse), APIError>) -> Void = { [weak self] result in
            switch result {
            case let .success((response, httpResponse)):
                // tell any listeners about the http response
                self?.callResponseListeners(
                    endpointName: request.endpoint,
                    result: .success(httpResponse)
                )
                
                // complete with success!
                completionQueue.async {
                    completion(.success(response))
                }
            case let .failure(error):
                
                // tell any listeners about the error
                self?.callResponseListeners(
                    endpointName: request.endpoint,
                    result: .failure(error)
                )
                
                // complete with failure :(
                completionQueue.async {
                    completion(.failure(error))
                }
            }
        }
        
        var endpointURL = self.baseURL.appendingPathComponent(request.endpoint)
        let headers = self.clientHeaders
        
        // add the request's queryParams to the url
        if !request.queryParams.isEmpty, var urlComps = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false) {
            urlComps.queryItems = request.queryParams.map({
                URLQueryItem(name: $0.key, value: $0.value)
            })
            
            if let urlWithParams = urlComps.url {
                endpointURL = urlWithParams
            }
        }
        
        // build the url request
        var urlReq = URLRequest(url: endpointURL, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)
        urlReq.httpMethod = request.method.rawValue
                
        var mergedHeaders: [String: String] = [:]
        
        // add the headers and request's headerOverrides
        for (key, value) in headers {
            mergedHeaders[key.lowercased()] = value
        }
        for (key, value) in request.headerOverrides {
            mergedHeaders[key.lowercased()] = value
        }
        
        urlReq.allHTTPHeaderFields = mergedHeaders
        
        // Encode the request's `body` property.
        // NOTE: the request will fail if it is a GET and this property is set.
        do {
            urlReq.httpBody = try request.body?.encode(self.defaultEncoder)
        } catch {
            // We were unable to make the request
            handleResult(.failure(.unencodableRequest(error: error)))
            return
        }
        let defaultDecoder = self.defaultDecoder
        let task = self.urlSession.dataTask(with: urlReq) { (data, urlResponse, error) in
            if let data = data, let httpResponse = urlResponse as? HTTPURLResponse {
                if (200..<300).contains(httpResponse.statusCode) {
                    do {
                        let successResponse = try request.decoder.decode(data, defaultDecoder)
                        // Successfully decoded the expected ResponseType!
                        handleResult(.success((successResponse, httpResponse)))
                        return
                    } catch let decodeError {
                        // Unable to decode the expected ResponseType.
                        handleResult(.failure(.decode(error: decodeError, data: data)))
                        return
                    }
                } else if let errorResponse = try? JSONDecoder().decode(APIError.ServerResponse.self, from: data) {
                    // We got a specific error object in the server's response.
                    handleResult(.failure(.server(errorResponse, httpResponse: httpResponse)))
                    return
                } else if let stringResponse = String(data: data, encoding: .utf8) {
                    // We got some error data in the server's response, but we cant decode it.
                    handleResult(.failure(.undecodableServer(stringResponse, httpResponse: httpResponse)))
                    return
                }
            }
            
            if let error = error {
                // We got a system networking error.
                handleResult(.failure(.network(error: error, urlResponse: urlResponse)))
                return
            } else {
                // The request failed for some unknown reason.
                handleResult(.failure(.failedRequest(urlResponse: urlResponse)))
                return
            }
        }
        task.resume()
    }
}

#if canImport(Future)
// MARK: - APIClient + Future

import Future

extension APIClient {
    public func send<ResponseType, VersionTag>(_ request: APIRequest<ResponseType, VersionTag>, completesOn: DispatchQueue = .main) -> Future<Result<ResponseType, APIError>> {
        .init(run: { [weak self] cb in
            self?.send(request, completesOn: completesOn, completion: cb)
        })
    }
}

#endif
