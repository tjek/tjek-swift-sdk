///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation
import TjekUtils

extension APIError {
    public var isRetryable: Bool {
        if isNetworkError(self) {
            return true
        } else if let httpResponse = self.httpURLResponse {
            let retryableStatuses: Set<Int> = [
                408,    // Request Timeout
                429,    // Too Many Requests
                502,    // Bad Gateway
                503,    // Service Unavailable
                504     // Gateway Timeout
            ]
            return retryableStatuses.contains(httpResponse.statusCode)
        } else {
            return false
        }
    }
}

extension APIError: HasUnderlyingError {
    /// return the underlying error, if there is one
    public var underlyingError: Error? {
        switch self {
        case .server,
             .undecodableServer,
             .failedRequest:
            return nil
        case .unencodableRequest(let error),
             .network(let error, _),
             .decode(let error, _),
             .unknown(let error):
            return error
        }
    }
}

// MARK: - Known API Errors

extension APIError.ServerResponse {

    public enum ErrorName: String, CaseIterable, CaseInsensitiveInitializable {
        case invalidAPIKey                  = "INVALID_API_KEY"
        
        case authTokenPersonDoesNotExist    = "AUTH_TOKEN_PERSON_DOES_NOT_EXIST"
        case authTokenExpired               = "AUTH_TOKEN_EXPIRED"
        case authTokenInvalid               = "AUTH_TOKEN_INVALID"
        case authTokenNoPersonIncluded      = "AUTH_TOKEN_NO_PERSON_INCLUDED"
        
        case invalidEmail                   = "INVALID_EMAIL"
        case invalidPassword                = "INVALID_PASSWORD"
        case emailAlreadyExists             = "EMAIL_ALREADY_EXISTS"
        
        case notFound                       = "NOT_FOUND"
        case invalidInput                   = "INVALID_INPUT"
        case duplicateContent               = "DUPLICATE_CONTENT"
        
        case offerNotFound                  = "OFFER_NOT_FOUND"
        
        /// An error that means the AuthToken passed to a request is no longer valid.
        /// All future requests will fail if the same token is passed.
        /// The AuthToken should be cleared, and the user should be logged out.
        public var isAuthTokenInvalid: Bool {
            switch self {
            case .authTokenPersonDoesNotExist,
                 .authTokenExpired,
                 .authTokenInvalid,
                 .authTokenNoPersonIncluded:
                return true
            default:
                return false
            }
        }
    }
    
    public var knownName: ErrorName? { ErrorName(caseInsensitive: self.name) }
}
