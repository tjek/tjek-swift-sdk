//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

public struct CoreAPIError: Error, Decodable {
    
    public var code: Int
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

extension CoreAPIError: CustomStringConvertible {
    public var description: String {
        // "CoreAPIError [session: 1107] 'missing token' (httpStatus: 400 / id: 00jbhp0ycrq192uwcxnzs56wt00wdprf) 'Missing token. No token found in request to an endpoint that requires a valid token.'"
        var string = "CoreAPIError [\(String(describing: category)): \(code)]"
        
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

extension CoreAPIError {
    
    public var category: ErrorCategory {
        switch self.code {
        case (1100...1199): return .session
        case (1200...1299): return .authentication
        case (1300...1399): return .authorization
        case (1400...1499): return .infoMissing
        case (1500...1599): return .infoInvalid
        case (1600...1699): return .rateControl
        case (2000...2099): return .internalIntegrity
        case (4000...4099): return .misc
        case (5000...5999): return .maintenance
        default: return .unknown
        }
    }
    
    public var errorConst: ErrorConst? {
        return ErrorConst(rawValue: code)
    }
    
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
    }
    
    /// All the error codes that are currently known to be emitted by the server
    public enum ErrorConst: Int {
        
        // Session errors
        case sessionError                       = 1100 // Session error.
        case sessionTokenExpired                = 1101 // Token has expired. You must create a new one to continue.
        case sessionInvalidAPIKey               = 1102 // Invalid API key. Could not find app matching your api key.
        case sessionMissingSignature            = 1103 // Missing signature. Only webpages are allowed to rely on domain name matching. Your request did not send the HTTP_HOST header, so you would have to supply a signature. See docs.
        case sessionInvalidSignature            = 1104 // Invalid signature. Signature given but did not match.
        case sessionTokenNotAllowed             = 1105 // Token not allowed. This token can not be used with this app. Ensure correct domain rules in app settings.
        case sessionMissingOrigin               = 1106 // Missing origin header. This token can not be used without a valid Origin header.
        case sessionMissingToken                = 1107 // Missing token. No token found in request to an endpoint that requires a valid token.
        case sessionInvalidToken                = 1108 // Invalid token. Token is not valid.
        case sessionInvalidOriginHeader         = 1110 // Invalid Origin header. Origin header does not match API App settings.
        
        // Authentication
        case authenticationError                = 1200 // Authentication error.
        case authenticationInvalidCredentials   = 1201 // User authorization failed. Did you supply the correct user credentials?
        case authenticationNoUser               = 1202 // User authorization failed. User not verified.
        case authenticationEmailNotVerified     = 1203 // User authorization failed. Supplied email not verfied. Check inbox.
        
        // Authorization
        case authorizationError                 = 1300 // Authorization error.
        case authorizationActionNotAllowed      = 1301 // Action not allowed within current session (permission error)
        
        // Missing Information
        case infoMissingError                   = 1400 // Request invalid due to missing information.
        case infoMissingGeolocation             = 1401 // Missing request location. This call requires a request location. See documentation.
        case infoMissingRadius                  = 1402 // Missing request radius. This call requires a request radius. See documentation.
        case infoMissingAuthentication          = 1411 // Missing authentication information You might need to supply authentication credentials in this request. See documentation.
        
        // Login specific information (facebook info could be missing, special code for each field)
        case infoMissingEmail                   = 1431 // Missing email property. You might be able to specify this manually. See documentation
        case infoMissingBirthday                = 1432 // Missing birthday property. You might be able to specify this manually. See documentation
        case infoMissingGender                  = 1433 // Missing gender property. You might be able to specify this manually. See documentation
        case infoMissingLocale                  = 1434 // Missing locale property. You might be able to specify this manually. See documentation
        case infoMissingName                    = 1435 // Missing name property. You might be able to specify this manually. See documentation
        case infoMissingResourceNotFound        = 1440 // Requested resource(s) not found
        case infoMissingResourceDeleted         = 1441 // Request resource not found because it has been deleted
        
        // Invalid Information
        case infoInvalid                        = 1500 // Invalid information
        case infoInvalidResourceID              = 1501 // Invalid resource id
        case infoInvalidResourceDuplication     = 1530 // Duplication of resource
        case infoInvalidBodyData                = 1566 // Invalid body data. Ensure body data is of valid syntax, and that you send a correct Content-Type header
        case infoInvalidProtocol                = 1568 // Invalid protocol
        
        // Rate Control
        case rateControlError                   = 1600 // You are sending to many requests in a short period of time
        case rateControlLimited                 = 1601 // You are being rate limited
        
        // Internal Corruption Of Data
        case internalIntegrityError             = 2000 // Internal integrity error. Please contact support with error id.
        case internalSearchError                = 2010 // Internal search error. Please contact support with error id.
        case internalNonCriticalError           = 2015 // Non-critical internal error. System trying to autofix. Please repeat request.
        
        // Misc.
        case miscActionNotExists                = 4000 // Action does not exist. Error message describes problem
        
        // Maintenance
        case maintenanceError                   = 5000 // Service is unavailable. We are working on it.
        case maintenanceErrorServiceDown        = 5010 // Service is down for maintainance (don't send requests)
        case maintenanceErrorFeatureDown        = 5020 // Feature is down for maintainance (Dont send same request again)
    }
}

// MARK: -

extension CoreAPIError {
    
    var isRetryable: Bool {
        guard let constErr = errorConst else { return false }
        switch constErr {
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
        guard let constErr = errorConst else { return false }
        
        switch constErr {
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
