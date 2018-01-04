//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

public struct ShopGunSDK {
    
    public struct Settings {
        public var coreAPI: CoreAPI.Settings?
        public var eventsTracker: EventsTracker.Settings?
        
        public init(coreAPI: CoreAPI.Settings?, eventsTracker: EventsTracker.Settings?) {
            self.coreAPI = coreAPI
            self.eventsTracker = eventsTracker
        }
        
        // TODO: need a way to get default settings from a .plist file
    }
    
    public enum LogLevel {
        case silent
        case important
        case verbose
    }
    
    // MARK: -
    
    private static var _shared: ShopGunSDK?
    
    public static func configure(settings: Settings) {
        
        var coreAPI: CoreAPI? = nil
        if let coreAPISettings = settings.coreAPI {
            if logLevel == .verbose {
                print("[ShopGunSDK] Configuring CoreAPI")
            }
            coreAPI = CoreAPI(settings: coreAPISettings, logLevel: self.logLevel)
        }
        
        var eventsTracker: EventsTracker? = nil
        if let eventsTrackerSettings = settings.eventsTracker {
            if logLevel == .verbose {
                print("[ShopGunSDK] Configuring EventsTracker")
            }
            eventsTracker = EventsTracker(settings: eventsTrackerSettings, logLevel: self.logLevel)
        }
        
        _shared = ShopGunSDK(coreAPI: coreAPI,
                             eventsTracker: eventsTracker)
    }
    
    public static var coreAPI: CoreAPI {
        guard let coreAPI = _shared?.coreAPI else {
            fatalError("Must configure ShopGunSDK with CoreAPI Settings")
        }
        return coreAPI
    }
    public static var hasCoreAPI: Bool {
        return _shared?.coreAPI != nil
    }
    
    public static var eventsTracker: EventsTracker {
        guard let eventsTracker = _shared?.eventsTracker else {
            fatalError("Must configure ShopGunSDK with EventsTracker Settings")
        }
        return eventsTracker
    }
    public static var hasEventsTracker: Bool {
        return _shared?.eventsTracker != nil
    }
    
    public static var logLevel: LogLevel = .important {
        didSet {
            _shared?.coreAPI?.logLevel = logLevel
            _shared?.eventsTracker?.logLevel = logLevel
        }
    }
    
    // MARK : -
    
    private init(coreAPI: CoreAPI?, eventsTracker: EventsTracker?) {
        self.coreAPI = coreAPI
        self.eventsTracker = eventsTracker
    }
    
    private let coreAPI: CoreAPI?
    private let eventsTracker: EventsTracker?
}
