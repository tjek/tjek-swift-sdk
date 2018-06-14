//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

extension CoreAPI.Requests {
    /**
     A request to fetch a specific `Offer`.
     
     - parameter offerId: The Id of the offer to request.
     - parameter locationQuery: If a location is provided, the resulting offer's `store` property will be set to the closest store where the offer is available
     */
    public static func getOffer(withId offerId: CoreAPI.Offer.Identifier, near locationQuery: LocationQuery?) -> CoreAPI.Request<CoreAPI.Offer> {
        return .init(path: "/v2/offers/\(offerId.rawValue)",
            method: .GET,
            requiresAuth: true)
    }
    
    public enum OffersSortOrder {
        case popularity
        
        fileprivate var sortKeys: [String] {
            switch self {
            case .popularity:
                return ["-popularity", "distance"]
            }
        }
    }
    
    /**
     Request all offers, optionally near a specific location.
     If no `sortOrder` is provided, it will be sorted by [.nearest, .businessName]
     
     - parameter locationQuery: Optionally filter results to a specific location.
     - parameter pagination: How many offers to include in the results, and with what offset. Defaults to the first 24.
     */
    public static func getOffers(near locationQuery: LocationQuery? = nil, sortedBy sortOrder: [OffersSortOrder]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Offer]> {
        
        var params: [String: String] = [:]
        
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let sortKeys = sortOrder?.flatMap({ $0.sortKeys }), sortKeys.count > 0 {
            params["order_by"] = sortKeys.joined(separator: ",")
        }
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/offers",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     * Builds a request that, when performed, will fetch all the active offers matching a `searchString`. The results can optionally be limited to those that have been published by a list of specified `Dealer` ids, and by their proximity to a location.
     *
     * - parameter searchString: The string to search for.
     * - parameter dealerIds: A list of `Dealer` identifiers defining which dealer's offers you want to fetch. Defaults to `nil`.
     * - parameter locationQuery: A `LocationQuery` that lets you filter the results around a specific location/radius. Defaults to `nil`.
     * - parameter pagination: A `PaginationQuery` that lets you specify how many publications you wish to fetch, and with what page offset.  Defaults to the first 24.
     */
    public static func getOffers(matchingSearch searchString: String, dealerIds: [CoreAPI.Dealer.Identifier]? = nil, near locationQuery: LocationQuery? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Offer]> {
        
        guard searchString.count > 0 else {
            return CoreAPI.Requests.getOffers(near: locationQuery, pagination: pagination)
        }
        
        var params: [String: String] = [:]
        
        params["query"] = searchString
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let dealerIds = dealerIds {
            params["dealer_ids"] = dealerIds.map(String.init).joined(separator: ",")
        }
        
        return .init(path: "/v2/offers/search",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    public static func getOffers(withStoreIds storeIds: [CoreAPI.Store.Identifier], near locationQuery: LocationQuery? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Offer]> {
        
        var params: [String: String] = [:]
        
        params["store_ids"] = storeIds.map(String.init).joined(separator: ",")
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        params.merge(pagination.requestParams) { (_, new) in new }

        return .init(path: "/v2/offers",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    public static func getOffers(withPublicationIds publicationIds: [CoreAPI.PagedPublication.Identifier], near locationQuery: LocationQuery? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Offer]> {
        
        var params: [String: String] = [:]
        
        params["catalog_ids"] = publicationIds.map(String.init).joined(separator: ",")
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/offers",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
}
