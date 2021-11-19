///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation
#if !COCOAPODS // Cocoapods merges these modules
import TjekUtils
#endif

public struct APIRequestEncoder {
    public var encode: (_ clientEncoder: JSONEncoder) throws -> Data?
    
    public init(_ encode: @escaping (_ clientEncoder: JSONEncoder) throws -> Data?) {
        self.encode = encode
    }
    
    public static func encodable<Input: Encodable>(_ input: Input, _ customEncoder: JSONEncoder? = nil) -> APIRequestEncoder {
        APIRequestEncoder { clientEncoder in
            try (customEncoder ?? clientEncoder).encode(input)
        }
    }
    public static func args(_ args: [String: JSONValue], _ customEncoder: JSONEncoder? = nil) -> APIRequestEncoder {
        encodable(args, customEncoder)
    }
    
    /// Adds a callback to the encoding action when it's performed.
    /// Use this to validate the data is as expected
    public func debugging(_ resultViewer: @escaping (Data?) -> Void) -> Self {
        APIRequestEncoder {
            let data = try self.encode($0)
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

public struct APIRequestDecoder<ResponseType> {
    public var decode: (Data, _ clientDecoder: JSONDecoder) throws -> ResponseType
    
    public init(_ decode: @escaping (Data, _ clientDecoder: JSONDecoder) throws -> ResponseType) {
        self.decode = decode
    }
    
    public func map<NewResponseType>(_ transform: @escaping (ResponseType) -> NewResponseType) -> APIRequestDecoder<NewResponseType> {
        APIRequestDecoder<NewResponseType> { data, clientDecoder in
            transform(try decode(data, clientDecoder))
        }
    }
    
    /// Adds a callback to the decoding action when it's performed.
    /// Use this to validate the data is as expected
    public func debugging(_ resultViewer: @escaping (Data, ResponseType) -> Void) -> Self {
        APIRequestDecoder { data, clientDecoder in
            let response = try decode(data, clientDecoder)
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

public enum APIRequestMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

public struct APIRequest<ResponseType, VersionTag> {
    
    public let endpoint: String
    public let method: APIRequestMethod
    /// NOTE, if `method` is GET and `body` is non-nil, the request will fail.
    public var body: APIRequestEncoder?
    public var queryParams: [String: String?]
    public var headerOverrides: [String: String?]
    public var timeoutInterval: TimeInterval
    public var cachePolicy: URLRequest.CachePolicy
    public var decoder: APIRequestDecoder<ResponseType>

    public init(endpoint: String, method: APIRequestMethod = .POST, body: APIRequestEncoder? = nil, queryParams: [String: String?] = [:], headerOverrides: [String: String?] = [:], timeoutInterval: TimeInterval = 10, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, decoder: APIRequestDecoder<ResponseType>) {
        self.endpoint = endpoint
        self.method = method
        self.body = body
        self.queryParams = queryParams
        self.headerOverrides = headerOverrides
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
        self.decoder = decoder
    }
}

// MARK: - Utils

extension APIRequest {
    /// Converts an APIRequest of one responseType into an APIRequest of a different type, by modifying the decoder.
    public func map<NewResponseType>(_ transform: @escaping (ResponseType) -> NewResponseType) -> APIRequest<NewResponseType, VersionTag> {
        return .init(endpoint: endpoint, method: method, body: body, queryParams: queryParams, headerOverrides: headerOverrides, timeoutInterval: timeoutInterval, cachePolicy: cachePolicy, decoder: decoder.map(transform))
    }
}

// MARK: - Decoder Overrides

extension APIRequestDecoder where ResponseType == Data {
    static var data: Self {
        APIRequestDecoder { data, _ in data }
    }
}
extension APIRequestDecoder where ResponseType: Decodable {
    static func decodable(_ customDecoder: JSONDecoder? = nil) -> Self {
        APIRequestDecoder { data, clientDecoder in
            try (customDecoder ?? clientDecoder).decode(ResponseType.self, from: data)
        }
    }
}
extension APIRequestDecoder where ResponseType == Void {
    static var void: Self {
        APIRequestDecoder { _, _ in () }
    }
}
extension APIRequestDecoder {
    static var jsonSerialization: Self {
        APIRequestDecoder { data, _ in
            guard let successValue = try JSONSerialization.jsonObject(with: data, options: []) as? ResponseType else {
                throw DecodingError.typeMismatch(ResponseType.self, DecodingError.Context(codingPath: [], debugDescription: "Unable to decode API request"))
            }
            return successValue
        }
    }
}

extension APIRequest where ResponseType == Data {
    public init(endpoint: String, method: APIRequestMethod = .POST, body: APIRequestEncoder? = nil, queryParams: [String: String?] = [:], headerOverrides: [String: String?] = [:], timeoutInterval: TimeInterval = 10, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        self.init(endpoint: endpoint, method: method, body: body, queryParams: queryParams, headerOverrides: headerOverrides, timeoutInterval: timeoutInterval, cachePolicy: cachePolicy, decoder: .data)
    }
}

extension APIRequest where ResponseType: Decodable {
    public init(endpoint: String, method: APIRequestMethod = .POST, body: APIRequestEncoder? = nil, queryParams: [String: String?] = [:], headerOverrides: [String: String?] = [:], timeoutInterval: TimeInterval = 10, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        self.init(endpoint: endpoint, method: method, body: body, queryParams: queryParams, headerOverrides: headerOverrides, timeoutInterval: timeoutInterval, cachePolicy: cachePolicy, decoder: .decodable())
    }
}

extension APIRequest where ResponseType == Void {
    public init(endpoint: String, method: APIRequestMethod = .POST, body: APIRequestEncoder? = nil, queryParams: [String: String?] = [:], headerOverrides: [String: String?] = [:], timeoutInterval: TimeInterval = 10, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        self.init(endpoint: endpoint, method: method, body: body, queryParams: queryParams, headerOverrides: headerOverrides, timeoutInterval: timeoutInterval, cachePolicy: cachePolicy, decoder: .void)
    }
}

extension APIRequest where ResponseType == [String: Any] {
    public init(endpoint: String, method: APIRequestMethod = .POST, body: APIRequestEncoder? = nil, queryParams: [String: String?] = [:], headerOverrides: [String: String?] = [:], timeoutInterval: TimeInterval = 10, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        self.init(endpoint: endpoint, method: method, body: body, queryParams: queryParams, headerOverrides: headerOverrides, timeoutInterval: timeoutInterval, cachePolicy: cachePolicy, decoder: .jsonSerialization)
    }
}

extension APIRequest where ResponseType == [[String: Any]] {
    public init(endpoint: String, method: APIRequestMethod = .POST, body: APIRequestEncoder? = nil, queryParams: [String: String?] = [:], headerOverrides: [String: String?] = [:], timeoutInterval: TimeInterval = 10, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        self.init(endpoint: endpoint, method: method, body: body, queryParams: queryParams, headerOverrides: headerOverrides, timeoutInterval: timeoutInterval, cachePolicy: cachePolicy, decoder: .jsonSerialization)
    }
}
