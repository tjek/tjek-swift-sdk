import Foundation

public struct APIPath {
    public var pathBuilder: (_ endpoint: String) -> String
    public var jsonEncoder: JSONEncoder
    public var jsonDecoder: JSONDecoder
}

extension APIPath {
    public static var v2: Self {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        return .init(pathBuilder: { "v2/\($0)" }, jsonEncoder: encoder, jsonDecoder: decoder)
    }

    public static var v4: Self {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .customISO8601(dateFormatter)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601(dateFormatter)

        return .init(pathBuilder: { "v4/rpc/\($0)" }, jsonEncoder: encoder, jsonDecoder: decoder)
    }
}

extension JSONEncoder.DateEncodingStrategy {
    fileprivate static func customISO8601(_ iso8601: ISO8601DateFormatter) -> Self {
        .custom({ date, encoder in
            var c = encoder.singleValueContainer()
            let dateStr = iso8601.string(from: date)
            try c.encode(dateStr)
        })
    }
}

extension JSONDecoder.DateDecodingStrategy {
    fileprivate static func customISO8601(_ iso8601: ISO8601DateFormatter) -> Self {
        .custom({ decoder in
            let c = try decoder.singleValueContainer()
            let dateStr = try c.decode(String.self)
            if let date = iso8601.date(from: dateStr) {
                return date
            } else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unable to decode date-string '\(dateStr)'")
            }
        })
    }
}

// MARK: -

extension APIRequest {
    public static func v4(endpoint: String, method: APIRequestMethod = .POST, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, responseDecoder: APIResponseDecoder<ResponseType>, shouldRetry: APIRequestRetryHandler = .nope) -> Self {
        Self.init(.v4, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { _ in responseDecoder }, shouldRetry: shouldRetry)
    }
    public static func v4(endpoint: String, method: APIRequestMethod = .POST, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, shouldRetry: APIRequestRetryHandler = .nope) -> Self where ResponseType: Decodable {
        Self.init(.v4, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { .decodable($0) }, shouldRetry: shouldRetry)
    }
    public static func v4(endpoint: String, method: APIRequestMethod = .POST, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, shouldRetry: APIRequestRetryHandler = .nope) -> Self where ResponseType == Void {
        Self.init(.v4, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { _ in .void }, shouldRetry: shouldRetry)
    }
    public static func v4(endpoint: String, method: APIRequestMethod = .POST, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, shouldRetry: APIRequestRetryHandler = .nope) -> Self where ResponseType == Data {
        Self.init(.v4, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { _ in .data }, shouldRetry: shouldRetry)
    }
    
    public static func v2(endpoint: String, method: APIRequestMethod, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, responseDecoder: APIResponseDecoder<ResponseType>, shouldRetry: APIRequestRetryHandler = .nope) -> Self {
        Self.init(.v2, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { _ in responseDecoder }, shouldRetry: shouldRetry)
    }
    public static func v2(endpoint: String, method: APIRequestMethod, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, shouldRetry: APIRequestRetryHandler = .nope) -> Self where ResponseType: Decodable {
        Self.init(.v2, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { .decodable($0) }, shouldRetry: shouldRetry)
    }
    public static func v2(endpoint: String, method: APIRequestMethod, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, shouldRetry: APIRequestRetryHandler = .nope) -> Self where ResponseType == Void {
        Self.init(.v2, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { _ in .void }, shouldRetry: shouldRetry)
    }
    public static func v2(endpoint: String, method: APIRequestMethod, queryParams: [String: String?] = [:], body bodyEncoder: APIRequestBodyEncoder? = nil, shouldRetry: APIRequestRetryHandler = .nope) -> Self where ResponseType == Data {
        Self.init(.v2, method: method, endpoint: endpoint, queryParams: queryParams, body: bodyEncoder, responseDecoder: { _ in .data }, shouldRetry: shouldRetry)
    }
    
    fileprivate init(_ apiPath: APIPath, method: APIRequestMethod, endpoint: String, queryParams: [String: String?], body bodyEncoder: APIRequestBodyEncoder?, responseDecoder: (JSONDecoder) -> APIResponseDecoder<ResponseType>, shouldRetry: APIRequestRetryHandler) {
        self.init(
            path: apiPath.pathBuilder(endpoint),
            method: method,
            queryParams: queryParams,
            bodyEncoder: bodyEncoder?.usingEncoder(apiPath.jsonEncoder),
            responseDecoder: responseDecoder(apiPath.jsonDecoder),
            shouldRetry: shouldRetry
        )
    }
}

// MARK: -

/// A typealias for the token type used to sign v2 & v4 requests.
public typealias AuthToken = String

extension URLRequest {
    public var authToken: AuthToken? {
        get {
            self.value(forHTTPHeaderField: "X-Token")
        }
        set {
            self.setValue(newValue, forHTTPHeaderField: "X-Token")
        }
    }
    
    public var apiKey: String? {
        get {
            self.value(forHTTPHeaderField: "X-Api-Key")
        }
        set {
            self.setValue(newValue, forHTTPHeaderField: "X-Api-Key")
        }
    }
}
