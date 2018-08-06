//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension Event {
    
    private enum ReservedSDKType: Int {
        case pagedPublicationOpened         = 1
        case pagedPublicationPageOpened     = 2
        case clientSessionOpened            = 4
    }
    
    internal static func pagedPublicationOpened(_ publicationId: CoreAPI.PagedPublication.Identifier, timestamp: Date = Date()) -> Event {
        let payload: PayloadType = ["pp.id": .string(publicationId.rawValue)]
        
        return Event(timestamp: timestamp,
                     type: ReservedSDKType.pagedPublicationOpened.rawValue,
                     payload: payload)
            .addingViewToken(contentId: publicationId.rawValue)
    }
    
    /// 1-indexed
    internal static func pagedPublicationPageOpened(_ publicationId: CoreAPI.PagedPublication.Identifier, pageNumber: Int, timestamp: Date = Date()) -> Event {
        let payload: PayloadType = ["pp.id": .string(publicationId.rawValue),
                                    "ppp.n": .int(pageNumber)]
        
        return Event(timestamp: timestamp,
                     type: ReservedSDKType.pagedPublicationPageOpened.rawValue,
                     payload: payload)
            .addingViewToken(contentId: "\(publicationId.rawValue).\(pageNumber)")
    }
    
    internal static func clientSessionOpened(timestamp: Date = Date()) -> Event {
        return Event(timestamp: timestamp,
                     type: ReservedSDKType.clientSessionOpened.rawValue)
    }
}
