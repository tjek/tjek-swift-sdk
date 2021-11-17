///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

// MARK: - Publication Requests

extension APIRequest {
    
    public static func getPublication(withId pubId: PublicationId) -> APIRequest<Publication_v2, API_v2> {
        APIRequest<Publication_v2, API_v2>(
            endpoint: "catalogs/\(pubId)",
            method: .GET
        )
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
    ) -> APIRequest<PaginatedResponse<Publication_v2, Int>, API_v2> {
        
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
        return APIRequest<[Publication_v2], API_v2>(
            endpoint: "catalogs",
            method: .GET,
            queryParams: params
        ).paginatedResponse(paginatedRequest: pagination)
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
