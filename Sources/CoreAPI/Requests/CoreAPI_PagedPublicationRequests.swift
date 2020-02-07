//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension CoreAPI.Requests {
    
    /// Fetch the details about the specified publication
    public static func getPagedPublication(withId pubId: CoreAPI.PagedPublication.Identifier) -> CoreAPI.Request<CoreAPI.PagedPublication> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)", method: .GET)
    }
    
    /// Fetch all the pages for the specified publication
    public static func getPagedPublicationPages(withId pubId: CoreAPI.PagedPublication.Identifier, aspectRatio: Double? = nil) -> CoreAPI.Request<[CoreAPI.PagedPublication.Page]> {
        return CoreAPI.Request<[CoreAPI.PagedPublication.Page]>(
            path: "/v2/catalogs/\(pubId.rawValue)/pages",
            method: .GET,
            resultMapper: {
                $0.decodeJSON().map({ (pageURLs: [ImageURLSet.CoreAPI.ImageURLs]) in
                    pageURLs.enumerated().map {
                        let images = ImageURLSet(fromCoreAPI: $0.element, aspectRatio: aspectRatio)
                        let pageIndex = $0.offset
                        return .init(index: pageIndex, title: "\(pageIndex+1)", aspectRatio: aspectRatio ?? 1.0, images: images)
                    }
                })
            }
        )
    }
    
    /// Fetch all hotspots for the specified publication
    /// The `aspectRatio` (w/h) of the publication is needed in order to position the hotspots correctly
    public static func getPagedPublicationHotspots(withId pubId: CoreAPI.PagedPublication.Identifier, aspectRatio: Double) -> CoreAPI.Request<[CoreAPI.PagedPublication.Hotspot]> {
        return CoreAPI.Request<[CoreAPI.PagedPublication.Hotspot]>(
            path: "/v2/catalogs/\(pubId.rawValue)/hotspots",
            method: .GET,
            resultMapper: {
                $0.decodeJSON().map({ (hotspots: [CoreAPI.PagedPublication.Hotspot]) in
                    hotspots.map({
                        /// We do this to convert out of the awful old V2 coord system (which was x: 0->1, y: 0->(h/w))
                        $0.withScaledBounds(scale: CGPoint(x: 1, y: aspectRatio))
                    })
                })
            }
        )
    }
    
    /// Given a publication's Id, this will return
    public static func getSuggestedPublications(relatedTo pubId: CoreAPI.PagedPublication.Identifier, near locationQuery: LocationQuery? = nil, acceptedTypes: Set<CoreAPI.PagedPublication.PublicationType> = [.paged, .incito], pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.PagedPublication]> {
        
        var params = ["catalog_id": pubId.rawValue]
        params.merge(pagination.requestParams) { (_, new) in new }
        
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        params["types"] = acceptedTypes.map({ $0.rawValue }).joined(separator: ",")

        return .init(path: "/v2/catalogs/suggest",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
}

// MARK: - Publication Lists

extension CoreAPI.Requests {
    
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
    
    public static func getPublications(near locationQuery: LocationQuery, sortedBy: PublicationSortOrder, acceptedTypes: Set<CoreAPI.PagedPublication.PublicationType> = [.paged, .incito], pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.PagedPublication]> {
        
        var params = ["order_by": sortedBy.sortKeys.joined(separator: ",")]
        params.merge(locationQuery.requestParams) { (_, new) in new }
        params.merge(pagination.requestParams) { (_, new) in new }
        params["types"] = acceptedTypes.map({ $0.rawValue }).joined(separator: ",")
        
        return .init(path: "/v2/catalogs",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    public static func getPublications(matchingSearch searchString: String, near locationQuery: LocationQuery? = nil, acceptedTypes: Set<CoreAPI.PagedPublication.PublicationType> = [.paged, .incito], pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.PagedPublication]> {
        
        var params = ["query": searchString]
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        params.merge(pagination.requestParams) { (_, new) in new }
        params["types"] = acceptedTypes.map({ $0.rawValue }).joined(separator: ",")
        
        return .init(path: "/v2/catalogs/search",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    public static func getPublications(forStores storeIds: [CoreAPI.Store.Identifier], acceptedTypes: Set<CoreAPI.PagedPublication.PublicationType> = [.paged, .incito], pagination: PaginatedQuery = PaginatedQuery(count: 24)) ->
        CoreAPI.Request<[CoreAPI.PagedPublication]> {
            var params = ["store_ids": storeIds.map(String.init).joined(separator: ",")]
            params.merge(pagination.requestParams) { (_, new) in new }
            params["types"] = acceptedTypes.map({ $0.rawValue }).joined(separator: ",")
            
            return .init(path: "/v2/catalogs",
                         method: .GET,
                         requiresAuth: true,
                         parameters: params)
    }
    
    /**
     * Builds a request that, when performed, will fetch all the actively published `PagedPublication`s for a list of specified `Dealer` ids.
     *
     * - parameter dealerIds: A list of `Dealer` identifiers defining which dealer's publications you want to fetch.
     * - parameter pagination: A `PaginationQuery` that lets you specify how many publications you wish to fetch, and with what page offset.
     */
    public static func getPublications(forDealers dealerIds: [CoreAPI.Dealer.Identifier], acceptedTypes: Set<CoreAPI.PagedPublication.PublicationType> = [.paged, .incito], pagination: PaginatedQuery = PaginatedQuery(count: 24)) ->
        CoreAPI.Request<[CoreAPI.PagedPublication]> {
            var params = ["dealer_ids": dealerIds.map(String.init).joined(separator: ",")]
            params.merge(pagination.requestParams) { (_, new) in new }
            params["types"] = acceptedTypes.map({ $0.rawValue }).joined(separator: ",")
            
            return .init(path: "/v2/catalogs",
                         method: .GET,
                         requiresAuth: true,
                         parameters: params)
    }
}
