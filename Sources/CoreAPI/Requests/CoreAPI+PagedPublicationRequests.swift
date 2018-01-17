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
    
    // TODO: add a load stores option?
    public static func getPagedPublication(withId pubId: CoreAPI.PagedPublication.Identifier) -> CoreAPI.Request<CoreAPI.PagedPublication> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)", method: .GET, timeoutInterval: 30)
    }
}
