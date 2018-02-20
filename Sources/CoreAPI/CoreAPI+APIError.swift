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
    
    public struct APIError: Error, Decodable {
        
        public struct Code: RawRepresentable, Hashable, Decodable {
            public let rawValue: Int
            
            public init(rawValue: Int) {
                self.rawValue = rawValue
            }
            public var hashValue: Int {
                return self.rawValue.hashValue
            }
        }
        
        public var code: Code
        public var id: String?
        public var message: String?
        public var details: String?
        public var previous: String?
        public var note: String?
        
        // non-decodable... can be added manually
        public var httpResponse: URLResponse? = nil
        
        // MARK: Generated
        
        public var httpStatusCode: Int? {
            return (httpResponse as? HTTPURLResponse)?.statusCode
        }
        
        // MARK: - Decodable
        
        public enum CodingKeys: String, CodingKey {
            case code
            case id
            case message
            case details
            case previous
            case note = "@note.1"
        }
    }
}

// MARK: -

private typealias CalculatedErrorAttributes = CoreAPI.APIError
extension CalculatedErrorAttributes {
    
    var isRetryable: Bool {
        switch self.code {
        case .internalNonCriticalError:
            return true
        default:
            return false
        }
    }
    
    /// Number of seconds until the request that triggered this error can be retried
    var canRetryAfter: TimeInterval? {
        guard isRetryable else { return nil }
        
        guard let retryAfter = (httpResponse as? HTTPURLResponse)?.allHeaderFields["Retry-After"] as? Int else {
            return nil
        }
        
        return TimeInterval(max(0, retryAfter))
    }
    
    var requiresRenewedAuthSession: Bool {
        switch self.code {
        case .sessionTokenExpired,
             .sessionInvalidSignature,
             .sessionMissingToken,
             .sessionInvalidToken:
            return true
        default:
            return false
        }
    }
}

// MARK: -

private typealias ErrorPrettyPrint = CoreAPI.APIError
extension ErrorPrettyPrint: CustomStringConvertible {
    public var description: String {
        // "CoreAPI.APIError [session: 1107] 'missing token' (httpStatus: 400 / id: 00jbhp0ycrq192uwcxnzs56wt00wdprf) 'Missing token. No token found in request to an endpoint that requires a valid token.'"
        var string = "CoreAPI.APIError [\(String(describing: code.category)): \(code.rawValue)]"
        
        if let msg = message {
            string.append(" '\(msg)'")
        }
        
        let additionalInfo: [(String, Any?)] = [("httpStatus", httpStatusCode),
                                                ("id", id)]
        let infoString: String = additionalInfo.reduce([String](), {
            guard let val = $1.1 else { return $0 }
            return $0 + ["\($1.0): \(val)"]
        }).joined(separator: " / ")
        if infoString.count > 0 {
            string.append(" (\(infoString))")
        }
        
        if let deets = details {
            string.append(" '\(deets.replacingOccurrences(of: "\n", with: ". "))'")
        }
        return string
    }
}

// MARK: -

private typealias ErrorCodeCategories = CoreAPI.APIError.Code
extension ErrorCodeCategories {
    
    public enum ErrorCategory {
        case unknown
        case session
        case authentication
        case authorization
        case infoMissing
        case infoInvalid
        case rateControl
        case internalIntegrity
        case misc
        case maintenance
        case client
    }
    
    public var category: ErrorCategory {
        switch self.rawValue {
        case (1100...1199): return .session
        case (1200...1299): return .authentication
        case (1300...1399): return .authorization
        case (1400...1499): return .infoMissing
        case (1500...1599): return .infoInvalid
        case (1600...1699): return .rateControl
        case (2000...2099): return .internalIntegrity
        case (4000...4099): return .misc
        case (5000...5999): return .maintenance
        case (-1100 ... -1000): return .client
        default:            return .unknown
        }
    }
}

// MARK: -

private typealias ErrorCodeConsts = CoreAPI.APIError.Code
extension ErrorCodeConsts {
    
    // MARK: - Session errors
    
    // Session error.
    public static var sessionError: CoreAPI.APIError.Code { return .init(rawValue: 1100) }
    // Token has expired. You must create a new one to continue.
    public static var sessionTokenExpired: CoreAPI.APIError.Code { return .init(rawValue: 1101) }
    // Invalid API key. Could not find app matching your api key.
    public static var sessionInvalidAPIKey: CoreAPI.APIError.Code { return .init(rawValue: 1102) }
    // Missing signature. Only webpages are allowed to rely on domain name matching. Your request did not send the HTTP_HOST header, so you would have to supply a signature. See docs.
    public static var sessionMissingSignature: CoreAPI.APIError.Code { return .init(rawValue: 1103) }
    // Invalid signature. Signature given but did not match.
    public static var sessionInvalidSignature: CoreAPI.APIError.Code { return .init(rawValue: 1104) }
    // Token not allowed. This token can not be used with this app. Ensure correct domain rules in app settings.
    public static var sessionTokenNotAllowed: CoreAPI.APIError.Code { return .init(rawValue: 1105) }
    // Missing origin header. This token can not be used without a valid Origin header.
    public static var sessionMissingOrigin: CoreAPI.APIError.Code { return .init(rawValue: 1106) }
    // Missing token. No token found in request to an endpoint that requires a valid token.
    public static var sessionMissingToken: CoreAPI.APIError.Code { return .init(rawValue: 1107) }
    // Invalid token. Token is not valid.
    public static var sessionInvalidToken: CoreAPI.APIError.Code { return .init(rawValue: 1108) }
    // Invalid Origin header. Origin header does not match API App settings.
    public static var sessionInvalidOriginHeader: CoreAPI.APIError.Code { return .init(rawValue: 1110) }
    
    // MARK: - Authentication
    
    // Authentication error.
    public static var authenticationError: CoreAPI.APIError.Code { return .init(rawValue: 1200) }
    // User authorization failed. Did you supply the correct user credentials?
    public static var authenticationInvalidCredentials: CoreAPI.APIError.Code { return .init(rawValue: 1201) }
    // User authorization failed. User not verified.
    public static var authenticationNoUser: CoreAPI.APIError.Code { return .init(rawValue: 1202) }
    // User authorization failed. Supplied email not verfied. Check inbox.
    public static var authenticationEmailNotVerified: CoreAPI.APIError.Code { return .init(rawValue: 1203) }
    
    // MARK: - Authorization
    
    // Authorization error.
    public static var authorizationError: CoreAPI.APIError.Code { return .init(rawValue: 1300) }
    // Action not allowed within current session (permission error)
    public static var authorizationActionNotAllowed: CoreAPI.APIError.Code { return .init(rawValue: 1301) }
    
    // MARK: - Missing Information
    
    // Request invalid due to missing information.
    public static var infoMissingError: CoreAPI.APIError.Code { return .init(rawValue: 1400) }
    // Missing request location. This call requires a request location. See documentation.
    public static var infoMissingGeolocation: CoreAPI.APIError.Code { return .init(rawValue: 1401) }
    // Missing request radius. This call requires a request radius. See documentation.
    public static var infoMissingRadius: CoreAPI.APIError.Code { return .init(rawValue: 1402) }
    // Missing authentication information You might need to supply authentication credentials in this request. See documentation.
    public static var infoMissingAuthentication: CoreAPI.APIError.Code { return .init(rawValue: 1411) }
    
    // Missing email property. You might be able to specify this manually. See documentation
    public static var infoMissingEmail: CoreAPI.APIError.Code { return .init(rawValue: 1431) }
    // Missing birthday property. You might be able to specify this manually. See documentation
    public static var infoMissingBirthday: CoreAPI.APIError.Code { return .init(rawValue: 1432) }
    // Missing gender property. You might be able to specify this manually. See documentation
    public static var infoMissingGender: CoreAPI.APIError.Code { return .init(rawValue: 1433) }
    // Missing locale property. You might be able to specify this manually. See documentation
    public static var infoMissingLocale: CoreAPI.APIError.Code { return .init(rawValue: 1434) }
    // Missing name property. You might be able to specify this manually. See documentation
    public static var infoMissingName: CoreAPI.APIError.Code { return .init(rawValue: 1435) }
    // Requested resource(s) not found
    public static var infoMissingResourceNotFound: CoreAPI.APIError.Code { return .init(rawValue: 1440) }
    // Request resource not found because it has been deleted
    public static var infoMissingResourceDeleted: CoreAPI.APIError.Code { return .init(rawValue: 1441) }
    
    // MARK: - Invalid Information
    
    // Invalid information
    public static var infoInvalid: CoreAPI.APIError.Code { return .init(rawValue: 1500) }
    // Invalid resource id
    public static var infoInvalidResourceID: CoreAPI.APIError.Code { return .init(rawValue: 1501) }
    // Duplication of resource
    public static var infoInvalidResourceDuplication: CoreAPI.APIError.Code { return .init(rawValue: 1530) }
    // Invalid body data. Ensure body data is of valid syntax, and that you send a correct Content-Type header
    public static var infoInvalidBodyData: CoreAPI.APIError.Code { return .init(rawValue: 1566) }
    // Invalid protocol
    public static var infoInvalidProtocol: CoreAPI.APIError.Code { return .init(rawValue: 1568) }
    
    // MARK: - Rate Control
    
    // You are sending to many requests in a short period of time
    public static var rateControlError: CoreAPI.APIError.Code { return .init(rawValue: 1600) }
    // You are being rate limited
    public static var rateControlLimited: CoreAPI.APIError.Code { return .init(rawValue: 1601) }
    
    // MARK: - Internal Corruption Of Data
    
    // Internal integrity error. Please contact support with error id.
    public static var internalIntegrityError: CoreAPI.APIError.Code { return .init(rawValue: 2000) }
    // Internal search error. Please contact support with error id.
    public static var internalSearchError: CoreAPI.APIError.Code { return .init(rawValue: 2010) }
    // Non-critical internal error. System trying to autofix. Please repeat request.
    public static var internalNonCriticalError: CoreAPI.APIError.Code { return .init(rawValue: 2015) }
    
    // MARK: - Misc.
    
    // Action does not exist. Error message describes problem
    public static var miscActionNotExists: CoreAPI.APIError.Code { return .init(rawValue: 4000) }
    
    // MARK: - Maintenance
    
    // Service is unavailable. We are working on it.
    public static var maintenanceError: CoreAPI.APIError.Code { return .init(rawValue: 5000) }
    // Service is down for maintainance (don't send requests)
    public static var maintenanceErrorServiceDown: CoreAPI.APIError.Code { return .init(rawValue: 5010) }
    // Feature is down for maintainance (Dont send same request again)
    public static var maintenanceErrorFeatureDown: CoreAPI.APIError.Code { return .init(rawValue: 5020) }
    
    // MARK: Client -
    
    public static var invalidNetworkResponseError: CoreAPI.APIError.Code { return .init(rawValue: -1000) }
    
    public static var unknownAPIError: CoreAPI.APIError.Code { return .init(rawValue: -1001) }
    
    public static var requestCancelled: CoreAPI.APIError.Code { return .init(rawValue: -1002) }
    
    public static var unableToLogin: CoreAPI.APIError.Code { return .init(rawValue: -1003) }
}

// MARK: -

private typealias ClientAPIErrorConsts = CoreAPI.APIError
extension ClientAPIErrorConsts {
    
    // When API responds with no status code & no data & no error (this is an unlikely situation
    public static func invalidNetworkResponseError(urlResponse: URLResponse?) -> CoreAPI.APIError { return .init(code: .invalidNetworkResponseError, id: nil, message: "Unknown network error", details: "The API responded with no HTTP status code, no data, and no error", previous: nil, note: nil, httpResponse: urlResponse) }
    
    // When API responds with a server or client http status code error, but data is not decodable into an CoreAPI.APIError
    public static func unknownAPIError(httpStatusCode: Int, urlResponse: URLResponse?) -> CoreAPI.APIError { return .init(code: .unknownAPIError, id: nil, message: "Unknown API error", details: "The API responded with an httpStatus error code, but malformed error json (reason: '\(HTTPURLResponse.localizedString(forStatusCode: httpStatusCode))')", previous: nil, note: nil, httpResponse: urlResponse) }
    
    // A request was cancelled
    public static var requestCancelled: CoreAPI.APIError {
        return .init(code: .requestCancelled, id: nil, message: "Request Cancelled", details: nil, previous: nil, note: nil, httpResponse: nil)
    }
    
    // A non-specific failure to login
    public static var unableToLogin: CoreAPI.APIError {
        return .init(code: .unableToLogin, id: nil, message: "Unable to Login", details: nil, previous: nil, note: nil, httpResponse: nil)
    }
}
