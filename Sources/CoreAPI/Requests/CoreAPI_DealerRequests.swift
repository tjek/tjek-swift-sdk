//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension CoreAPI.Requests {
    
    /**
     A request to fetch a specific dealer.
     
     - parameter dealerId: The Id of the dealer to request.
     */
    public static func getDealer(withId dealerId: CoreAPI.Dealer.Identifier) -> CoreAPI.Request<CoreAPI.Dealer> {
        return .init(path: "/v2/dealers/\(dealerId.rawValue)",
                     method: .GET,
                     requiresAuth: true)
    }
    
    public static func getDealers(pagination: PaginatedQuery = PaginatedQuery(count: 24)) -> CoreAPI.Request<[CoreAPI.Dealer]> {
        
        var params: [String: String] = [:]
        params.merge(pagination.requestParams) { (_, new) in new }
        
        return .init(path: "/v2/dealers",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
    
    /**
     A request to fetch a list of `Dealer` objects.
     
     - parameter dealerIds: An array of dealer ids to fetch. The resulting list of dealers will be limited to those with the specified ids.
     - parameter pagination: Use to specify how many objects to fetch, and with what start cursor (offset). Defaults to the first 100 objects.
     */
    public static func getDealers(withIds dealerIds: [CoreAPI.Dealer.Identifier], pagination: PaginatedQuery = PaginatedQuery(count: 100)) -> CoreAPI.Request<[CoreAPI.Dealer]> {
        
        var params: [String: String] = [:]
        params.merge(pagination.requestParams) { (_, new) in new }

        params["dealer_ids"] = dealerIds.map({ $0.rawValue }).joined(separator: ",")
        
        return .init(path: "/v2/dealers",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
}
