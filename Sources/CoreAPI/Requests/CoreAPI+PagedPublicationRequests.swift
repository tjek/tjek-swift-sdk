//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import CoreLocation

extension CoreAPI.Requests {
    
    public struct PaginatedQuery {
        public var startCursor: Int
        public var itemCount: Int
        
        public init(start: Int = 0, count: Int) {
            self.startCursor = start
            self.itemCount = count
        }
        
        fileprivate var requestParams: [String: String] {
            return ["offset": String(self.startCursor),
                    "limit": String(self.itemCount)]
        }
    }
    
    public struct LocationQuery {
        public var coordinate: CLLocationCoordinate2D
        public var radius: CLLocationDistance?
        public var isFromSensor: Bool
        
        public init(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance?, isFromSensor: Bool) {
            self.coordinate = coordinate
            self.radius = radius
            self.isFromSensor = isFromSensor
        }
        
        fileprivate var requestParams: [String: String] {
            var params: [String: String] = [:]
            
            params["r_lat"] = String(self.coordinate.latitude)
            params["r_lng"] = String(self.coordinate.longitude)
            params["r_sensor"] = self.isFromSensor ? "true" : "false"
            
            if let radius = self.radius {
                params["r_radius"] = String(radius)
            }
            return params
        }
    }
    
    // TODO: add a load stores option?
    /// Fetch the details about the specified publication
    public static func getPagedPublication(withId pubId: CoreAPI.PagedPublication.Identifier) -> CoreAPI.Request<CoreAPI.PagedPublication> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)", method: .GET, timeoutInterval: 30)
    }
    
    /// Fetch all the pages for the specified publication
    public static func getPagedPublicationPages(withId pubId: CoreAPI.PagedPublication.Identifier, aspectRatio: Double? = nil) -> CoreAPI.Request<[CoreAPI.PagedPublication.Page]> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)/pages", method: .GET, timeoutInterval: 30, resultMapper: {
            return $0.map {
                // map the raw array of imageURLSets into objects containing page indexes
                let pageURLs = try JSONDecoder().decode([ImageURLSet.CoreAPIImageURLs].self, from: $0)
                return pageURLs.enumerated().map {
                    let images = ImageURLSet(fromCoreAPI: $0.element, aspectRatio: aspectRatio)
                    let pageIndex = $0.offset
                    return .init(index: pageIndex, title: "\(pageIndex+1)", aspectRatio: aspectRatio ?? 1.0, images: images)
                }
            }
        })
    }

    /// Fetch all hotspots for the specified publication
    /// The `aspectRatio` (w/h) of the publication is needed in order to position the hotspots correctly
    public static func getPagedPublicationHotspots(withId pubId: CoreAPI.PagedPublication.Identifier, aspectRatio: Double) -> CoreAPI.Request<[CoreAPI.PagedPublication.Hotspot]> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)/hotspots", method: .GET, timeoutInterval: 30, resultMapper: {
            return $0.map {
                return try JSONDecoder().decode([CoreAPI.PagedPublication.Hotspot].self, from: $0).map {
                    /// We do this to convert out of the awful old V2 coord system (which was x: 0->1, y: 0->(h/w))
                    return $0.withScaledBounds(scale: CGPoint(x: 1, y: aspectRatio))
                }
            }
        })
    }
    
    /// Given a publication's Id, this will return
    public static func getSuggestedPublications(relatedTo pubId: CoreAPI.PagedPublication.Identifier, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.PagedPublication]> {
        
        var params = ["catalog_id": pubId.rawValue]
        params.merge(pagination.requestParams) { (_, new) in new }

        return .init(path: "/v2/catalogs/suggest",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params,
                     timeoutInterval: 30)
    }
    
    public enum PublicationSortOrder {
        case nameAtoZ
        case popularity
        case newestPublished
        case nearest
        case oldestExpiry
        
        fileprivate var sortKeys: [String] {
            switch self {
            case .nameAtoZ:
                return ["name"]
            case .popularity:
                return ["-popularity", "distance"]
            case .newestPublished:
                return ["-publication_date", "distance"]
            case .nearest:
                return ["distance"]
            case .oldestExpiry:
                return ["expiration_date", "distance"]
            }
        }
    }
    
    // TODO: Load stores option
    public static func getPublications(near locationQuery: LocationQuery, sortedBy: PublicationSortOrder, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.PagedPublication]> {
        
        var params = ["order_by": sortedBy.sortKeys.joined(separator: ",")]
        params.merge(locationQuery.requestParams) { (_, new) in new }
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/catalogs",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params,
                     timeoutInterval: 30)
    }
    
    // TODO: Load stores option. or a way to pipe requests together
    public static func getFavoritedPublications(sortedBy: PublicationSortOrder, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.PagedPublication]> {
        
        var params = ["order_by": sortedBy.sortKeys.joined(separator: ",")]
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/catalogs/favorites",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params,
                     timeoutInterval: 30)
    }
}
