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
    /**
     A request to fetch a specific `Store`.
     
     - parameter storeId: The Id of the store to request.
     */
    public static func getStore(withId storeId: CoreAPI.Store.Identifier) -> CoreAPI.Request<CoreAPI.Store> {
        return .init(path: "/v2/stores/\(storeId.rawValue)",
            method: .GET,
            requiresAuth: true)
    }
    
    // TODO: include a LocationQuery. Sort order? Paginatate only when no ids?
    /**
     A request to fetch `Store` objects.
     
     - parameter storeIds: An optional array of store ids to fetch. If included (and not empty) the resulting list of stores will be limited to those with the specified ids.
     - parameter pagination: Use to specify how many objects to fetch, and with what start cursor (offset). Defaults to the first 100 objects.
     */

    public static func getStores(withIds storeIds: [CoreAPI.Store.Identifier]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 100)) -> CoreAPI.Request<[CoreAPI.Store]> {
        
        // If we have only a single store Id, use the 'getStore' request, and map the result into an array
        if let firstStoreId = storeIds?.first, storeIds?.count == 1 {
            return .init(request: self.getStore(withId: firstStoreId)) {
                $0.mapValue({ [$0] })
            }
        }
        
        var params: [String: String] = [:]
        params.merge(pagination.requestParams) { (_, new) in new }
        
        if let storeIds = storeIds {
            params["store_ids"] = storeIds.map({ $0.rawValue }).joined(separator: ",")
        }
        
        return .init(path: "/v2/stores",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
}
