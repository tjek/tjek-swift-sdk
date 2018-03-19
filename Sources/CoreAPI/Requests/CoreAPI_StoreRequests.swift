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
    
    public enum StoresSortOrder {
        case nearest
        
        fileprivate var sortKeys: [String] {
            switch self {
            case .nearest:
                return ["distance"]
            }
        }
    }
    
    /**
     A request to fetch a specific `Store`.
     
     - parameter storeId: The Id of the store to request.
     */
    public static func getStore(withId storeId: CoreAPI.Store.Identifier) -> CoreAPI.Request<CoreAPI.Store> {
        return .init(path: "/v2/stores/\(storeId.rawValue)",
            method: .GET,
            requiresAuth: true)
    }
    
    /**
     A request to fetch specific `Store` objects.
     
     - parameter storeIds: An array of store ids to fetch.
     - parameter pagination:  How many stores to include in the results, and with what offset. Defaults to the first 100.
     */
    public static func getStores(withIds storeIds: [CoreAPI.Store.Identifier], pagination: PaginatedQuery = PaginatedQuery(count: 100)) -> CoreAPI.Request<[CoreAPI.Store]> {
        var params = ["store_ids": storeIds.map({ $0.rawValue }).joined(separator: ",")]
        params.merge(pagination.requestParams) { (_, new) in new }

        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Request all stores, optionally near a specific location.
     
     - parameter locationQuery: Optionally filter results to a specific location.
     - parameter pagination: How many stores to include in the results, and with what offset. Defaults to the first 24.
     */
    public static func getStores(near locationQuery: LocationQuery? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params: [String: String] = [:]
        params.merge(pagination.requestParams) { (_, new) in new }
        
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }

        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores that match the specified search string, optionally limited to a specific location.
     */
    public static func getStores(matchingSearch searchString: String, near locationQuery: LocationQuery? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        guard searchString.count > 0 else {
            return CoreAPI.Requests.getStores(near: locationQuery, pagination: pagination)
        }
        
        var params = ["query": searchString]
        
        params.merge(pagination.requestParams) { (_, new) in new }
        
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        
        return .init(path: "/v2/stores/search",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores for the specified list of dealers.
     */
    public static func getStores(withDealerIds dealerIds: [CoreAPI.Dealer.Identifier], near locationQuery: LocationQuery? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params = ["dealer_ids": dealerIds.map({ $0.rawValue }).joined(separator: ",")]
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores for the specified list of publications.
     */
    public static func getStores(withPublicationIds publicationIds: [CoreAPI.PagedPublication.Identifier], near locationQuery: LocationQuery? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params = ["catalog_ids": publicationIds.map({ $0.rawValue }).joined(separator: ",")]
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores for the specified list of offers.
     */
    public static func getStores(withOfferIds offerIds: [CoreAPI.Offer.Identifier], near locationQuery: LocationQuery? = nil, sortedBy: StoresSortOrder? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params = ["offer_ids": offerIds.map({ $0.rawValue }).joined(separator: ",")]
        params.merge(pagination.requestParams) { (_, new) in new }
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let sortKeys = sortedBy?.sortKeys {
            params["order_by"] = sortKeys.joined(separator: ",")
        }
        
        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
}
