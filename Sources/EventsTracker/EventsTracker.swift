//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public final class EventsTracker {
    
    public struct Settings {
        public var trackId: String
        public var baseURL: URL
        public var dispatchInterval: TimeInterval
        public var dispatchLimit: Int
    }
    
    public let settings: Settings
    
    public init(settings: Settings) {
        self.settings = settings
    }
}

extension EventsTracker.Settings {
    public static func `default`(trackId: String) -> EventsTracker.Settings {
        return .init(trackId: trackId, baseURL: URL(string: "https://events.service-staging.shopgun.com")!, dispatchInterval: 120, dispatchLimit: 100)
    }
}
