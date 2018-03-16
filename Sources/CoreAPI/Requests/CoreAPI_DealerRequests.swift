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
    
    // TODO: include a LocationQuery. Sort order? Paginatate only when no ids?
    /**
     A request to fetch `Dealer` objects.
     
     - parameter dealerIds: An optional array of dealer ids to fetch. If included (and not empty) the resulting list of dealers will be limited to those with the specified ids.
     - parameter pagination: Use to specify how many objects to fetch, and with what start cursor (offset). Defaults to the first 100 objects.
     */
    public static func getDealers(withIds dealerIds: [CoreAPI.Dealer.Identifier]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 100)) -> CoreAPI.Request<[CoreAPI.Dealer]> {
        
        // If we have only a single dealer Id, use the 'getDealer' request, and map the result into an array
        if let firstDealerId = dealerIds?.first, dealerIds?.count == 1 {
            return .init(request: self.getDealer(withId: firstDealerId)) {
                $0.mapValue({ [$0] })
            }
        }
        
        var params: [String: String] = [:]
        params.merge(pagination.requestParams) { (_, new) in new }

        if let dealerIds = dealerIds {
            params["dealer_ids"] = dealerIds.map({ $0.rawValue }).joined(separator: ",")
        }
        
        return .init(path: "/v2/dealers",
                     method: .GET,
                     requiresAuth: true,
                     parameters: params)
    }
}
