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
    /// Fetch all dealers
    // TODO: location, pagination
    public static func allDealers() -> CoreAPI.Request<[CoreAPI.Dealer]> {
        return .init(path: "/v2/dealers", method: .GET, timeoutInterval: 30)
    }
}
