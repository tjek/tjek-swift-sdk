///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation
#if !COCOAPODS // Cocoapods merges these modules
import TjekUtils
#endif

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

    public enum ErrorName: String, CaseIterable {
        case notFound                       = "NOT_FOUND"
        case invalidInput                   = "INVALID_INPUT"
        case duplicateContent               = "DUPLICATE_CONTENT"
        case noAccess                       = "NO_ACCESS"
        
        case invalidAPIKey                  = "INVALID_API_KEY"
        case tokenInvalid                   = "TOKEN_INVALID"
        
        case authTokenPersonDoesNotExist    = "AUTH_TOKEN_PERSON_DOES_NOT_EXIST"
        case authTokenNoPersonAdmin         = "AUTH_TOKEN_NO_PERSON_ADMIN"
        case authTokenExpired               = "AUTH_TOKEN_EXPIRED"
        case authTokenInvalid               = "AUTH_TOKEN_INVALID"
        case authTokenNoPersonIncluded      = "AUTH_TOKEN_NO_PERSON_INCLUDED"
        
        case invalidEmail                   = "INVALID_EMAIL"
        case invalidPassword                = "INVALID_PASSWORD"
        case emailAlreadyExists             = "EMAIL_ALREADY_EXISTS"
        
        case offerNotFound                  = "OFFER_NOT_FOUND"
        case offersNotFound                 = "OFFERS_NOT_FOUND"
        case catalogNotFound                = "CATALOG_NOT_FOUND"
        case incitoNotFound                 = "INCITO_NOT_FOUND"
        
        /// An error that means the AuthToken passed to a request is no longer valid.
        /// All future requests will fail if the same token is passed.
        /// The AuthToken should be cleared, and the user should be logged out.
        public var isAuthTokenInvalid: Bool {
            switch self {
            case .authTokenExpired,
                 .authTokenInvalid,
                 .authTokenPersonDoesNotExist,
                 .authTokenNoPersonIncluded,
                 .authTokenNoPersonAdmin:
                return true
            default:
                return false
            }
        }
        
        public var code: Int {
            switch self {
            case .noAccess,
                    .tokenInvalid,
                    .invalidAPIKey:
                return 1102 // no access
            case .authTokenExpired:
                return 1101
            case .authTokenInvalid:
                return 1108
            case .authTokenPersonDoesNotExist,
                    .authTokenNoPersonIncluded,
                    .authTokenNoPersonAdmin:
                return 1300 // invalid session
            case .invalidInput,
                    .invalidEmail,
                    .invalidPassword:
                return 1400 // invalid input
            case .duplicateContent,
                    .emailAlreadyExists:
                return 1530 // content already exists
            case .notFound,
                    .offerNotFound,
                    .offersNotFound,
                    .catalogNotFound,
                    .incitoNotFound:
                return 1501 // not found
            }
        }
    }
    
    /// Try to match a known error based on it's name, and if that fails, match based on the code.
    public var knownName: ErrorName? {
        if let nameMatch = ErrorName.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(self.name) == .orderedSame }) {
            return nameMatch
        } else if let codeMatch = ErrorName.allCases.first(where: { $0.code == self.code }) {
            return codeMatch
        } else {
            return nil
        }
    }
}
