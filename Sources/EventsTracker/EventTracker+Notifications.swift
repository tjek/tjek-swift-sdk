//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension Notification.Name {
    
    /// Create an 'eventTracked' notification name for a specific event-type.
    /// If no type is provided the returned name will catch _all_ event types.
    /// This notification can be queried on a specific tracker object.
    /// `userInfo` includes `type`, `uuid`, & (optionally) `properties` & `view` keys.
    public static func eventTracked(type: String? = nil) -> Notification.Name {
        var name = "ShopGunSDK.EventsTracker.eventTracked"
        if let fullType = type {
            name += "." + fullType
        }
        return Notification.Name(name)
    }
}
