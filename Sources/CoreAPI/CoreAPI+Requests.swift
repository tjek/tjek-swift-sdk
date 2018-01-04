//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

// MARK: -

public enum HTTPRequestMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

public protocol CoreAPIRequestable {
    associatedtype ResponseType: Decodable
    
    var path: String { get }
    var method: HTTPRequestMethod { get }
    var parameters: [String: String]? { get }
    var timeoutInterval: TimeInterval { get }
    
    var requiresAuth: Bool { get }
    var maxRetryCount: Int { get }
    func urlRequest(for baseURL: URL, additionalParameters: [String: String]) -> URLRequest
}

extension CoreAPIRequestable {
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
    
    // The simple concrete implementation of the CoreAPIRequestable protocol
    public struct Request<T: Decodable>: CoreAPIRequestable {
        public typealias ResponseType = T
        
        public var path: String
        public var method: HTTPRequestMethod
        public var parameters: [String: String]?
        public var timeoutInterval: TimeInterval
        public var requiresAuth: Bool
        public var maxRetryCount: Int

        public init(path: String, method: HTTPRequestMethod, requiresAuth: Bool = true, parameters: [String: String]? = nil, timeoutInterval: TimeInterval = 30, maxRetryCount: Int = 3) {
            self.path = path
            self.method = method
            self.parameters = parameters
            self.timeoutInterval = timeoutInterval
            self.requiresAuth = requiresAuth
            self.maxRetryCount = maxRetryCount
        }
    }
}
