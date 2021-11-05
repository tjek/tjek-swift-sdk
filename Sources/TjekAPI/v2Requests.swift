///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

/// A 'versioned' wrapper of APIRequest, meaning you dont accidentally use the wrong request with the wrong API version.
public struct APIv2Request<ResponseType> {
    var request: APIRequest<ResponseType>
    
    public init(_ request: APIRequest<ResponseType>) {
        self.request = request
    }
}

extension APIRequest {
    public var v2Request: APIv2Request<ResponseType> { APIv2Request<ResponseType>(self) }
}

extension TjekAPI {
    
    /// Send an API Request to the v4 API client.
    /// The result is received in the `completion` handler, on the `completesOn` queue (defaults to `.main`).
    public func send<ResponseType>(v2 request: APIRequest<ResponseType>, completesOn: DispatchQueue = .main, completion: @escaping (Result<ResponseType, APIError>) -> Void) {
        v2.send(request, completesOn: completesOn, completion: completion)
    }
    
    /// Send a v4-specific API Request to the v4 API client.
    /// The result is received in the `completion` handler, on the `completesOn` queue (defaults to `.main`).
    public func send<ResponseType>(_ v2Req: APIv2Request<ResponseType>, completesOn: DispatchQueue = .main, completion: @escaping (Result<ResponseType, APIError>) -> Void) {
        send(v2: v2Req.request, completesOn: completesOn, completion: completion)
    }
}

#if canImport(Future)
import Future
extension TjekAPI {
    
    /// Returns a Future, which, when run, sends an API Request to the v4 API client.
    /// Future's completion-handler is called on the `completesOn` queue (defaults to `.main`)
    public func send<ResponseType>(v2 request: APIRequest<ResponseType>, completesOn: DispatchQueue = .main) -> Future<Result<ResponseType, APIError>> {
        v2.send(request, completesOn: completesOn)
    }
    
    /// Returns a Future, which, when run, sends a v4-specific API Request to the v4 API client.
    /// Future's completion-handler is called on the `completesOn` queue (defaults to `.main`)
    public func send<ResponseType>(_ v2Req: APIv2Request<ResponseType>, completesOn: DispatchQueue = .main) -> Future<Result<ResponseType, APIError>> {
        send(v2: v2Req.request, completesOn: completesOn)
    }
}
#endif

// MARK: - Publication Requests

extension APIv2Request {
    
    public static func getPublication(withId pubId: PublicationId) -> APIv2Request<Publication_v2> {
        .init(APIRequest<Publication_v2>(
            endpoint: "catalogs/\(pubId)",
            method: .GET
        ))
    }
    /**
     Return a paginated list of publications, limited by the parameters.
     
     - Parameters:
        - businessIds: Limit the list of publications by the id of the business that published them.
        - storeIds: Limit the list of publications by the ids of the stores they cover.
        - near: Specify a coordinate to return publications in relation to. Also optionally limit the publications to within a max radius from that coordinate.
        - acceptedTypes: Choose which types of publications to return (defaults to all)
        - pagination: The count & cursor of the request's page. Defaults to the first page. maxPageSize=100, maxCursorOffset=1000
     */
    public static func getPublications(
        businessIds: Set<BusinessId> = [],
        storeIds: Set<StoreId> = [],
        near location: LocationQuery? = nil,
        acceptedTypes: Set<Publication_v2.PublicationType> = Set(Publication_v2.PublicationType.allCases),
        pagination: PaginatedRequest<Int> = .firstPage(24)
    ) -> APIv2Request<PaginatedResponse<Publication_v2, Int>> {
        
        var params = ["types": acceptedTypes.map(\.rawValue).joined(separator: ",")]
        params.merge(pagination.v2RequestParams()) { (_, new) in new }
        
        if !businessIds.isEmpty {
            params["dealer_ids"] = businessIds.map(\.rawValue).joined(separator: ",")
        }
        if !businessIds.isEmpty {
            params["store_ids"] = storeIds.map(\.rawValue).joined(separator: ",")
        }
        if let locationQ = location {
            params.merge(locationQ.v2RequestParams()) { (_, new) in new }
        }
//        if let sortOrder = sortOrder {
//            params["order_by"] = sortOrder.sortKeys.joined(separator: ",")
//        }
        return .init(APIRequest<[Publication_v2]>(
            endpoint: "catalogs",
            method: .GET,
            queryParams: params
        ).paginatedResponse(paginatedRequest: pagination))
    }
}

// MARK: - v2 Request Utils

extension LocationQuery {
    public func v2RequestParams() -> [String: String] {
        var params = [
            "r_lat": String(coordinate.latitude),
            "r_lng": String(coordinate.longitude)
        ]
        
        if let radius = maxRadius {
            params["r_radius"] = String(radius)
        }
        return params
    }
}

extension PaginatedRequest {
    public func v2RequestParams() -> [String: String] where CursorType == Int {
        [
            "offset": String(self.startCursor),
            "limit": String(self.itemCount)
        ]
    }
    
    public func v2RequestParams() -> [String: String] where CursorType == String {
        [
            "offset": self.startCursor,
            "limit": String(self.itemCount)
        ]
    }
    
    public func v2RequestParams() -> [String: String] where CursorType == String? {
        [
            "offset": self.startCursor,
            "limit": String(self.itemCount)
        ].compactMapValues({ $0 })
    }
}

/// A convert the v2 image response dictionary into a set of sized image urls
public struct v2ImageURLs: Decodable {
    public let thumb: URL?
    public let view: URL?
    public let zoom: URL?
    
    public var imageURLSet: Set<ImageURL> {
        Set([
            thumb.map({ ImageURL(url: $0, width: 177) }),
            view.map({ ImageURL(url: $0, width: 768) }),
            zoom.map({ ImageURL(url: $0, width: 1536) })
        ].compactMap({ $0 }))
    }
}
