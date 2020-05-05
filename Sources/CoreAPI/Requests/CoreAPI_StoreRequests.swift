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
        case businessName
        
        fileprivate var sortKeys: [String] {
            switch self {
            case .nearest:
                return ["distance"]
            case .businessName:
                return ["dealer"]
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
     If no `sortOrder` is provided, it will be sorted by [.nearest, .businessName]

     - parameter storeIds: An array of store ids to fetch.
     - parameter pagination:  How many stores to include in the results, and with what offset. Defaults to the first 100.
     */
    public static func getStores(withIds storeIds: [CoreAPI.Store.Identifier], sortedBy sortOrder: [StoresSortOrder]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 100)) -> CoreAPI.Request<[CoreAPI.Store]> {
        var params = ["store_ids": storeIds.map(String.init).joined(separator: ",")]
        params.merge(pagination.requestParams) { (_, new) in new }

        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Request all stores, optionally near a specific location.
     If no `sortOrder` is provided, it will be sorted by [.nearest, .businessName]

     - parameter locationQuery: Optionally filter results to a specific location.
     - parameter pagination: How many stores to include in the results, and with what offset. Defaults to the first 24.
     */
    public static func getStores(near locationQuery: LocationQuery? = nil, sortedBy sortOrder: [StoresSortOrder]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params: [String: String] = [:]
        
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let sortKeys = sortOrder?.flatMap({ $0.sortKeys }), sortKeys.count > 0 {
            params["order_by"] = sortKeys.joined(separator: ",")
        }
        params.merge(pagination.requestParams) { (_, new) in new }

        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores that match the specified search string, optionally limited to a specific location.
     If no `sortOrder` is provided, it will be sorted by [.nearest, .businessName]
     If searchString is empty it will just get all stores near the locationQuery.
     */
    public static func getStores(matchingSearch searchString: String, near locationQuery: LocationQuery? = nil, sortedBy sortOrder: [StoresSortOrder]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        guard searchString.count > 0 else {
            return CoreAPI.Requests.getStores(near: locationQuery, sortedBy: sortOrder, pagination: pagination)
        }
        
        var params = ["query": searchString]
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let sortKeys = sortOrder?.flatMap({ $0.sortKeys }), sortKeys.count > 0 {
            params["order_by"] = sortKeys.joined(separator: ",")
        }
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/stores/search",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores for the specified list of dealers.
     If no `sortOrder` is provided, it will be sorted by [.nearest, .businessName]
     Note: If a locationQuery is provided, the stores will be limited to that location. HOWEVER, if the stores are in a different country to the publication, the resulting stores will be any store filtered by the locationQuery. This is an API issue.
     */
    public static func getStores(withDealerIds dealerIds: [CoreAPI.Dealer.Identifier], near locationQuery: LocationQuery? = nil, sortedBy sortOrder: [StoresSortOrder]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params = ["dealer_ids": dealerIds.map(String.init).joined(separator: ",")]
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let sortKeys = sortOrder?.flatMap({ $0.sortKeys }), sortKeys.count > 0 {
            params["order_by"] = sortKeys.joined(separator: ",")
        }
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores for the specified list of publications.
     If no `sortOrder` is provided, it will be sorted by [.nearest, .businessName]
     Note: If a locationQuery is provided, the stores will be limited to that location. HOWEVER, if the stores are in a different country to the publication, the resulting stores will be any store filtered by the locationQuery. This is an API issue.
     */
    public static func getStores(withPublicationIds publicationIds: [PublicationIdentifier], near locationQuery: LocationQuery? = nil, sortedBy sortOrder: [StoresSortOrder]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params = ["catalog_ids": publicationIds.map(String.init).joined(separator: ",")]
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let sortKeys = sortOrder?.flatMap({ $0.sortKeys }), sortKeys.count > 0 {
            params["order_by"] = sortKeys.joined(separator: ",")
        }
        params.merge(pagination.requestParams) { (_, new) in new }

        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     Get all the stores for the specified list of offers.
     If no `sortOrder` is provided, it will be sorted by [.nearest, .businessName]
     Note: If a locationQuery is provided, the stores will be limited to that location. HOWEVER, if the stores are in a different country to the publication, the resulting stores will be any store filtered by the locationQuery. This is an API issue.
     */
    public static func getStores(withOfferIds offerIds: [CoreAPI.Offer.Identifier], near locationQuery: LocationQuery? = nil, sortedBy sortOrder: [StoresSortOrder]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        var params = ["offer_ids": offerIds.map(String.init).joined(separator: ",")]
        if let locationQParams = locationQuery?.requestParams {
            params.merge(locationQParams) { (_, new) in new }
        }
        if let sortKeys = sortOrder?.flatMap({ $0.sortKeys }), sortKeys.count > 0 {
            params["order_by"] = sortKeys.joined(separator: ",")
        }
        params.merge(pagination.requestParams) { (_, new) in new }

        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
}
