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
    var parameters: [String: String]? { get }
    var timeoutInterval: TimeInterval { get }
    
    var requiresAuth: Bool { get }
    var maxRetryCount: Int { get }
    
    func urlRequest(for baseURL: URL, additionalParameters: [String: String]) -> URLRequest
}

public protocol CoreAPIMappableRequest: CoreAPIRequest {
    associatedtype ResponseType // the type that is returned after mapping input data
    
    typealias ResultMapper = ((Result<Data>) -> (Result<ResponseType>))
    var resultMapper: ResultMapper { get }
}

extension CoreAPIRequest {
    // default implementation of the urlRequest generator
    public func urlRequest(for baseURL: URL, additionalParameters: [String: String] = [:]) -> URLRequest {
        var requestURL = baseURL.appendingPathComponent(path)
        
        // put parameters into url of request
        if var urlComps = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) {
            // merge the requests params and the additionalParams, favoring the reqs params
            var allParams = self.parameters ?? [:]
            allParams.merge(additionalParameters) { (reqParam, _) in reqParam }
            
            urlComps.queryItems = allParams.map { (key, value) in
                URLQueryItem(name: key, value: value)
            }
            
            urlComps.percentEncodedQuery = urlComps.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            
            if let urlWithParams = urlComps.url {
                requestURL = urlWithParams
            }
        }

        var urlRequest = URLRequest(url: requestURL, timeoutInterval: timeoutInterval)
        urlRequest.httpMethod = method.rawValue
        
        return urlRequest
    }
}

extension CoreAPI {
    
    // The simple concrete implementation of the CoreAPIMappableRequest protocol
    public struct Request<T>: CoreAPIMappableRequest {
        public typealias ResponseType = T

        public var path: String
        public var method: HTTPRequestMethod
        public var parameters: [String: String]?
        public var timeoutInterval: TimeInterval
        public var requiresAuth: Bool
        public var maxRetryCount: Int
        public var resultMapper: ((Result<Data>) -> (Result<T>))

        public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String]? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3, resultMapper: @escaping ResultMapper) {
            self.path = path
            self.method = method
            self.parameters = parameters
            self.timeoutInterval = timeoutInterval
            self.requiresAuth = requiresAuth
            self.maxRetryCount = maxRetryCount
            self.resultMapper = resultMapper
        }
        
        /**
         Create a request based on another request, with the ResponseType remapped using the resultMapper.
         */
        public init<U>(request: Request<U>, resultMapper: @escaping ((Result<U>) -> (Result<T>))) {
            self.path = request.path
            self.method = request.method
            self.parameters = request.parameters
            self.timeoutInterval = request.timeoutInterval
            self.requiresAuth = request.requiresAuth
            self.maxRetryCount = request.maxRetryCount
            self.resultMapper = { resultMapper(request.resultMapper($0)) }
        }
    }
}

extension CoreAPI.Request where T: Decodable {
    /// If we know the responseType is decodable then allow for Request creation with a default jsonDecoder resultMapper.
    public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String]? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3) {
        self.init(path: path, method: method, requiresAuth: requiresAuth, parameters: parameters, timeoutInterval: timeoutInterval, maxRetryCount: maxRetryCount, resultMapper: { $0.decodeJSON() })
    }
}

extension CoreAPI.Request where T == Void {
    /// If we know the responseType is Void then map the result data into a void
    public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String]? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3) {
        self.init(path: path, method: method, requiresAuth: requiresAuth, parameters: parameters, timeoutInterval: timeoutInterval, maxRetryCount: maxRetryCount, resultMapper: { $0.mapValue({ _ in return () }) })
    }
}

extension CoreAPI.Request where T == [String: Any] {
    /// If we know the responseType is a generic dictionary then map the result data using the JSONSerialization Foundation api
    public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String]? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3) {
        self.init(path: path, method: method, requiresAuth: requiresAuth, parameters: parameters, timeoutInterval: timeoutInterval, maxRetryCount: maxRetryCount, resultMapper: {
            $0.mapValue({ data in
                guard let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Error!"))
                }
                return jsonDict
            })
        })
    }
}
