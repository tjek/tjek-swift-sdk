///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation

public protocol HasUnderlyingError {
    var underlyingError: Error? { get }
}

public func isNetworkError(_ error: Error) -> Bool {
    if let underlyingError = (error as? HasUnderlyingError)?.underlyingError {
        return isNetworkError(underlyingError)
    }
    
    let nsErr = error as NSError
    
    guard nsErr.domain == NSURLErrorDomain else {
        return false
    }
    
    switch nsErr.code {
    case NSURLErrorTimedOut,
         NSURLErrorNotConnectedToInternet,
         NSURLErrorNetworkConnectionLost,
         NSURLErrorCannotFindHost,
         NSURLErrorCannotConnectToHost,
         NSURLErrorDNSLookupFailed,
         NSURLErrorInternationalRoamingOff,
         NSURLErrorCallIsActive,
         NSURLErrorDataNotAllowed,
         NSURLErrorResourceUnavailable,
         NSURLErrorBadServerResponse,
         NSURLErrorFileDoesNotExist,
         NSURLErrorNoPermissionsToReadFile:
        return true
    default:
        return false
    }
}

public func isNotNetworkError(_ error: Error) -> Bool {
    !isNetworkError(error)
}
