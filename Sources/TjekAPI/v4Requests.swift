///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

/// A 'versioned' wrapper of APIRequest, meaning you dont accidentally use the wrong request with the wrong API version.
public struct APIv4Request<ResponseType> {
    var request: APIRequest<ResponseType>
    
    public init(_ request: APIRequest<ResponseType>) {
        self.request = request
    }
    
    public func map<NewResponseType>(_ transform: @escaping (ResponseType) -> NewResponseType) -> APIv4Request<NewResponseType> {
        APIv4Request<NewResponseType>(self.request.map(transform))
    }
}

extension APIRequest {
    public var v4Request: APIv4Request<ResponseType> { APIv4Request<ResponseType>(self) }
}

extension TjekAPI {
    
    /// Send an API Request to the v4 API client.
    /// The result is received in the `completion` handler, on the `completesOn` queue (defaults to `.main`).
    public func send<ResponseType>(v4 request: APIRequest<ResponseType>, completesOn: DispatchQueue = .main, completion: @escaping (Result<ResponseType, APIError>) -> Void) {
        v4.send(request, completesOn: completesOn, completion: completion)
    }
    
    /// Send a v4-specific API Request to the v4 API client.
    /// The result is received in the `completion` handler, on the `completesOn` queue (defaults to `.main`).
    public func send<ResponseType>(_ v4Req: APIv4Request<ResponseType>, completesOn: DispatchQueue = .main, completion: @escaping (Result<ResponseType, APIError>) -> Void) {
        send(v4: v4Req.request, completesOn: completesOn, completion: completion)
    }
}

#if canImport(Future)
import Future
extension TjekAPI {
    
    /// Returns a Future, which, when run, sends an API Request to the v4 API client.
    /// Future's completion-handler is called on the `completesOn` queue (defaults to `.main`)
    public func send<ResponseType>(v4 request: APIRequest<ResponseType>, completesOn: DispatchQueue = .main) -> Future<Result<ResponseType, APIError>> {
        v4.send(request, completesOn: completesOn)
    }
    
    /// Returns a Future, which, when run, sends a v4-specific API Request to the v4 API client.
    /// Future's completion-handler is called on the `completesOn` queue (defaults to `.main`)
    public func send<ResponseType>(_ v4Req: APIv4Request<ResponseType>, completesOn: DispatchQueue = .main) -> Future<Result<ResponseType, APIError>> {
        send(v4: v4Req.request, completesOn: completesOn)
    }
}
#endif

extension APIv4Request {

}
