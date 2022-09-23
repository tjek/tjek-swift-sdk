///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation
//#if !COCOAPODS // Cocoapods merges these modules
//import TjekUtils
//#endif

public struct APIRequest<ResponseType> {
    public let path: String
    public let method: APIRequestMethod
    public var queryParams: [String: String?]
    public var urlRequestBuilder: URLRequestBuilder
    public var bodyEncoder: APIRequestBodyEncoder?
    public var responseDecoder: APIResponseDecoder<ResponseType>
    public var shouldRetry: APIRequestRetryHandler
    
    public init(
        path: String,
        method: APIRequestMethod,
        queryParams: [String: String?] = [:],
        urlRequestBuilder: @escaping URLRequestBuilder = { _ in },
        bodyEncoder: APIRequestBodyEncoder?,
        responseDecoder: APIResponseDecoder<ResponseType>,
        shouldRetry: APIRequestRetryHandler
    ) {
        self.path = path
        self.method = method
        self.queryParams = queryParams
        self.urlRequestBuilder = urlRequestBuilder
        self.bodyEncoder = bodyEncoder
        self.responseDecoder = responseDecoder
        self.shouldRetry = shouldRetry
    }
    
    private func generateURL(fromBaseURL baseURL: URL) throws -> URL {
        // add the query params to the url
        let requestURL = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        else {
            throw URLError(.badURL)
        }
        if !queryParams.isEmpty {
            components.queryItems = queryParams.map({
                URLQueryItem(name: $0.key, value: $0.value)
            })
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
    
    public func generateURLRequest(baseURL: URL, defaultJSONEncoder: JSONEncoder) async throws -> URLRequest {
        let endpointURL = try generateURL(fromBaseURL: baseURL)
        
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = try await bodyEncoder?.encode(defaultJSONEncoder)
        
        try await urlRequestBuilder(&urlRequest)
        
        return urlRequest
    }
}

extension APIRequest {
    /// Converts an APIRequest of one responseType into an APIRequest of a different type, by modifying the decoder.
    public func mapResponse<NewResponseType>(
        _ transform: @escaping (ResponseType) -> NewResponseType
    ) -> APIRequest<NewResponseType> {
        APIRequest<NewResponseType>(
            path: self.path,
            method: self.method,
            queryParams: self.queryParams,
            urlRequestBuilder: self.urlRequestBuilder,
            bodyEncoder: self.bodyEncoder,
            responseDecoder: self.responseDecoder.map(transform),
            shouldRetry: self.shouldRetry
        )
    }
}

extension APIRequest {
    public func addingURLRequestBuilder(_ reqBuilder: @escaping URLRequestBuilder) -> Self {
        var copy = self
        let prevReqBuilder = self.urlRequestBuilder
        copy.urlRequestBuilder = { urlReq in
            try await prevReqBuilder(&urlReq)
            try await reqBuilder(&urlReq)
        }
        return copy
    }
    
    public func with(headers: [String: String?]) -> Self {
        self.addingURLRequestBuilder { urlReq in
            for (key, value) in headers {
                urlReq.setValue(value, forHTTPHeaderField: key)
            }
        }
    }
    
    public func with(cachePolicy: URLRequest.CachePolicy) -> Self {
        self.addingURLRequestBuilder { $0.cachePolicy = cachePolicy }
    }
    
    public func with(timeoutInterval: TimeInterval) -> Self {
        self.addingURLRequestBuilder { $0.timeoutInterval = timeoutInterval }
    }
}

extension APIRequest {
    public func retry(_ retry: APIRequestRetryHandler) -> Self {
        var copy = self
        copy.shouldRetry = retry
        return copy
    }
    
    public func retry(times: Int, whileError: @escaping (APIError) -> Bool) -> Self {
        retry(.times(times, whileError: whileError))
    }
}


// MARK: -

public enum APIRequestMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

public typealias URLRequestBuilder = (inout URLRequest) async throws -> Void
public typealias URLRequestBodyBuilder = () async throws -> Data?

public struct APIRequestRetryHandler {
    public typealias ErrorType = APIError
    
    public let predicate: (_ count: Int, _ error: ErrorType) -> Bool
    
    public static var nope: Self {
        .init { _, _ in false }
    }
    
    public static var once: Self { .times(1) }
    
    public static func times(_ maxRetryCount: Int, whileError: @escaping (ErrorType) -> Bool = { _ in true }) -> Self {
        .init { count, error in
            count < maxRetryCount && whileError(error)
        }
    }
}

// MARK: -

public struct APIRequestBodyEncoder {
    public var encode: (JSONEncoder) async throws -> Data?
    
    public init(_ encode: @escaping (JSONEncoder) async throws -> Data?) {
        self.encode = encode
    }
    public init(_ data: Data? = nil) {
        self.init({ _ in data })
    }
    
    public static func encodable(_ inputBuilder: @escaping () async throws -> Encodable?) -> Self {
        self.init { jsonEncoder in
            guard let input = try await inputBuilder() else {
                return nil
            }
            return try jsonEncoder.encode(input)
        }
    }
    
    public static func encodable(_ input: Encodable?) -> Self {
        self.init { jsonEncoder in
            try input.map({ try jsonEncoder.encode($0) })
        }
    }
    
    public func usingEncoder(_ newEncoder: JSONEncoder) -> Self {
        Self { _ in
            try await self.encode(newEncoder)
        }
    }
    
    /// Adds a callback to the encoding action when it's performed.
    /// Use this to validate the data is as expected
    public func debugging(_ resultViewer: @escaping (Data?) -> Void) -> Self {
        APIRequestBodyEncoder { jsonEncoder in
            let data = try await self.encode(jsonEncoder)
            resultViewer(data)
            return data
        }
    }
    public func printDebugData(prefix: String = "") -> Self {
        self.debugging {
            print(prefix + ($0.flatMap({ String(data: $0, encoding: .utf8) }) ?? "<No Data>"))
        }
    }
}

// MARK: -

public struct APIResponseDecoder<ResponseType> {
    public var decode: (Data) async throws -> ResponseType
    
    public init(_ decode: @escaping (Data) async throws -> ResponseType) {
        self.decode = decode
    }
    
    public func map<NewResponseType>(_ transform: @escaping (ResponseType) async throws -> NewResponseType) -> APIResponseDecoder<NewResponseType> {
        APIResponseDecoder<NewResponseType> { data in
            try await transform(try await decode(data))
        }
    }
    
    /// Adds a callback to the decoding action when it's performed.
    /// Use this to validate the data is as expected
    public func debugging(_ resultViewer: @escaping (Data, ResponseType) -> Void) -> Self {
        APIResponseDecoder { data in
            let response = try await decode(data)
            resultViewer(data, response)
            return response
        }
    }
    public func printDebugData(prefix: String = "") -> Self {
        self.debugging { data, _ in
            print(prefix + (String(data: data, encoding: .utf8) ?? "<No Data>"))
        }
    }
}

extension APIResponseDecoder where ResponseType == Data {
    public static var data: Self {
        APIResponseDecoder { $0 }
    }
}
extension APIResponseDecoder where ResponseType: Decodable {
    public static func decodable(_ decoder: JSONDecoder) -> Self {
        APIResponseDecoder { data in
            try decoder.decode(ResponseType.self, from: data)
        }
    }
}
extension APIResponseDecoder where ResponseType == Void {
    public static var void: Self {
        APIResponseDecoder { _ in () }
    }
}
extension APIResponseDecoder {
    public static var jsonSerialization: Self {
        APIResponseDecoder { data in
            guard let successValue = try JSONSerialization.jsonObject(with: data, options: []) as? ResponseType else {
                throw DecodingError.typeMismatch(ResponseType.self, DecodingError.Context(codingPath: [], debugDescription: "Unable to decode API request"))
            }
            return successValue
        }
    }
}
