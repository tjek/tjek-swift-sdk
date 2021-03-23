//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public enum HTTPRequestMethod: String {
    case GET, POST, PUT, DELETE
}

public protocol CoreAPIRequest {
    var path: String { get }
    var method: HTTPRequestMethod { get }
    var parameters: [String: String?]? { get }
    var httpBody: Any? { get }
    var timeoutInterval: TimeInterval { get }
    
    var requiresAuth: Bool { get }
    var maxRetryCount: Int { get }
    
    func urlRequest(for baseURL: URL, additionalParameters: [String: String?]) -> URLRequest
}

public protocol CoreAPIMappableRequest: CoreAPIRequest {
    associatedtype ResponseType // the type that is returned after mapping input data
    
    typealias ResultMapper = ((Result<Data, Error>) -> (Result<ResponseType, Error>))
    var resultMapper: ResultMapper { get }
}

extension CoreAPIRequest {
    // default implementation of the urlRequest generator
    public func urlRequest(for baseURL: URL, additionalParameters: [String: String?] = [:]) -> URLRequest {
        var requestURL = baseURL.appendingPathComponent(path)
        
        // put parameters into url of request
        if var urlComps = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) {
            
            let allParams = (self.parameters ?? [:]).merging(additionalParameters) { (reqParam, _) in reqParam }

            urlComps.queryItems = allParams.map { (key, value) in
                URLQueryItem(name: key, value: value)
            }
            
            // This is a super-hacky hack because for some reason our server doesn't accept unencoded `+` characters
            // Server-side fix is pending.
            urlComps.percentEncodedPath = urlComps.percentEncodedPath.replacingOccurrences(of: "+", with: "%2B")
            
            if let urlWithParams = urlComps.url {
                requestURL = urlWithParams
            }
        }

        var urlRequest = URLRequest(url: requestURL, timeoutInterval: timeoutInterval)
        urlRequest.httpMethod = method.rawValue
        
        if let httpBody = self.httpBody {
            do {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: httpBody, options: [])
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch let error {
                Logger.log("Unable to JSONSerialize the Request's httpBody \(error.localizedDescription)", level: .error, source: .CoreAPI)
            }
        }
        
        return urlRequest
    }
}

extension CoreAPI {
    
    // The simple concrete implementation of the CoreAPIMappableRequest protocol
    public struct Request<T>: CoreAPIMappableRequest {
        public typealias ResponseType = T

        public var path: String
        public var method: HTTPRequestMethod
        public var parameters: [String: String?]?
        public var httpBody: Any?
        public var timeoutInterval: TimeInterval
        public var requiresAuth: Bool
        public var maxRetryCount: Int
        public var resultMapper: ((Result<Data, Error>) -> (Result<T, Error>))

        public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String?]? = nil, httpBody: Any? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3, resultMapper: @escaping ResultMapper) {
            self.path = path
            self.method = method
            self.parameters = parameters
            self.httpBody = httpBody
            self.timeoutInterval = timeoutInterval
            self.requiresAuth = requiresAuth
            self.maxRetryCount = maxRetryCount
            self.resultMapper = resultMapper
        }
        
        /**
         Create a request based on another request, with the ResponseType remapped using the resultMapper.
         */
        public init<U>(request: Request<U>, resultMapper: @escaping ((Result<U, Error>) -> (Result<T, Error>))) {
            self.path = request.path
            self.method = request.method
            self.parameters = request.parameters
            self.httpBody = request.httpBody
            self.timeoutInterval = request.timeoutInterval
            self.requiresAuth = request.requiresAuth
            self.maxRetryCount = request.maxRetryCount
            self.resultMapper = { resultMapper(request.resultMapper($0)) }
        }
    }
}

extension CoreAPI.Request where T: Decodable {
    /// If we know the responseType is decodable then allow for Request creation with a default jsonDecoder resultMapper.
    public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String?]? = nil, httpBody: Any? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3, jsonDecoder: JSONDecoder = JSONDecoder()) {
        self.init(path: path, method: method, requiresAuth: requiresAuth, parameters: parameters, httpBody: httpBody, timeoutInterval: timeoutInterval, maxRetryCount: maxRetryCount, resultMapper: { $0.decodeJSON(with: jsonDecoder) })
    }
}

extension CoreAPI.Request where T == Void {
    /// If we know the responseType is Void then map the result data into a void
    public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String?]? = nil, httpBody: Any? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3) {
        self.init(
            path: path,
            method: method,
            requiresAuth: requiresAuth,
            parameters: parameters,
            httpBody: httpBody,
            timeoutInterval: timeoutInterval,
            maxRetryCount: maxRetryCount,
            resultMapper: { $0.map({ _ in () }) }
        )
    }
}

extension CoreAPI.Request where T == [String: Any] {
    /// If we know the responseType is a generic dictionary then map the result data using the JSONSerialization Foundation api
    public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String?]? = nil, httpBody: Any? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3) {
        self.init(
            path: path,
            method: method,
            requiresAuth: requiresAuth,
            parameters: parameters,
            httpBody: httpBody,
            timeoutInterval: timeoutInterval,
            maxRetryCount: maxRetryCount,
            resultMapper: { $0.decodeJSONObject() }
        )
    }
}

extension CoreAPI.Request where T == [[String: Any]] {
    /// If we know the responseType is an array of generic dictionaries then map the result data using the JSONSerialization Foundation api
    public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String?]? = nil, httpBody: Any? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3) {
        self.init(
            path: path,
            method: method,
            requiresAuth: requiresAuth,
            parameters: parameters,
            httpBody: httpBody,
            timeoutInterval: timeoutInterval,
            maxRetryCount: maxRetryCount,
            resultMapper: { $0.decodeJSONObject() }
        )
    }
}
