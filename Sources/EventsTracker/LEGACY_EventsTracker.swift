//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

// Just stuff to get it building until EventsTracker is rebuilt properly

/// A container for representing an id in an event's properties
@objc(SGNIdField)
public class IdField: NSObject {
    public let id: String
    public let source: String
    
    public init?(_ id: String?, source: String) {
        guard id != nil else { return nil }
        self.id = id!
        self.source = source
    }
    
    public func jsonArray() -> [String] {
        return [source, id]
    }
    
    public static func legacy(_ id: String?) -> IdField? {
        return IdField(id, source: "legacy")
    }
    public static func graph(_ id: String?) -> IdField? {
        return IdField(id, source: "graph")
    }
}

public extension Notification.Name {
    
    /// Create an 'eventTracked' notification name for a specific event-type.
    /// If no type is provided the returned name will catch _all_ event types.
    /// This notification can be queried on a specific tracker object.
    /// `userInfo` includes `type`, `uuid`, & (optionally) `properties` & `view` keys.
    static func eventTracked(type: String? = nil) -> Notification.Name {
        var name = "ShopGunSDK.EventsTracker.eventTracked"
        if let fullType = type {
            name += "." + fullType
        }
        return Notification.Name(name)
    }
    
    /// This notification is triggered if there is a (non-networking) error when shipping an event.
    /// A notification will be created for each failed event.
    /// This notification will not be tied to any specific tracker.
    /// `userInfo` includes `status`, `response`, `event`, & (optionally) `removingFromCache` keys
    static let eventShipmentFailed = Notification.Name("ShopGunSDK.EventsTracker.eventShipmentFailed")
}

extension EventsTracker {
    /// Allows the client to attach view information to all future events.
    public func updateView(_ path: [String]? = nil, uri: String? = nil, previousPath: [String]? = nil) {
        // TODO: Properly when EventsKit rewritten!
    }
    public func trackEvent(_ type: String, properties: [String: AnyObject]?) {
        // TODO: Properly when EventsKit rewritten!
    }
    
    public var personId: IdField? {
        get { return nil }
        set { }
    }
}
