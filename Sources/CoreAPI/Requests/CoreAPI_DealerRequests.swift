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
    // TODO: include a LocationQuery. Maybe split into 2 requests?
    /**
     A request to fetch `Dealer` objects.
     
     - parameter dealerIds: An optional array of dealer ids to fetch. If included (and not empty) the resulting list of dealers will be limited to those with the specified ids.
     - parameter pagination: Use to specify how many objects to fetch, and with what start cursor (offset). Defaults to the first 100 objects.
     */
    public static func dealers(withIds dealerIds: [CoreAPI.Dealer.Identifier]? = nil, pagination: PaginatedQuery = PaginatedQuery(count: 100)) -> CoreAPI.Request<[CoreAPI.Dealer]> {
        
        var params: [String: String] = [:]
        params.merge(pagination.requestParams) { (_, new) in new }

        var path = "/v2/dealers"
        if let dealerIds = dealerIds {
            if dealerIds.count == 1, let dealerId = dealerIds.first {
                path += "/\(dealerId)"
            } else {
                params["dealer_ids"] = dealerIds.map({ $0.rawValue }).joined(separator: ",")
            }
        }
        
        return .init(path: path,
                     method: .GET,
                     requiresAuth: true,
                     parameters: params,
                     timeoutInterval: 30)
    }
}
