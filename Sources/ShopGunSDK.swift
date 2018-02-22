//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public struct ShopGunSDK {
    
    public typealias LogHandler = (_ message: String, _ level: LogLevel, _ source: LogSource, _ location: (file: String, function: String, line: Int)) -> Void
    
    public struct Settings {
        public var coreAPI: CoreAPI.Settings?
        public var eventsTracker: EventsTracker.Settings?
        
        // if this is set then secure data will available to other apps (check entitlements)
        public var sharedKeychainGroupId: String?
        
        public init(coreAPI: CoreAPI.Settings?, eventsTracker: EventsTracker.Settings?, sharedKeychainGroupId: String? = nil) {
            self.coreAPI = coreAPI
            self.eventsTracker = eventsTracker
            self.sharedKeychainGroupId = sharedKeychainGroupId
        }
        
        // TODO: need a way to get default settings from a .plist file
    }
    
    // MARK: -
    
    public static func configure(settings: Settings, logHandler: LogHandler? = nil) {
        
        // TODO: setup logHandler first
        let dataStore: ShopGunSDKSecureDataStore
        if ShopGunSDK.isRunningInPlayground {
            dataStore = PlaygroundDataStore()
        } else {
            dataStore = KeychainDataStore(sharedKeychainGroupId: settings.sharedKeychainGroupId)
        }
        
        var coreAPI: CoreAPI? = nil
        if let coreAPISettings = settings.coreAPI {
            ShopGunSDK.log("Configuring CoreAPI", level: .verbose, source: .ShopGunSDK)
            coreAPI = CoreAPI(settings: coreAPISettings, secureDataStore: dataStore)
        }
        
        var eventsTracker: EventsTracker? = nil
        if let eventsTrackerSettings = settings.eventsTracker {
            ShopGunSDK.log("Configuring EventsTracker", level: .verbose, source: .ShopGunSDK)
            eventsTracker = EventsTracker(settings: eventsTrackerSettings)
        }
        
        _shared = ShopGunSDK(coreAPI: coreAPI,
                             eventsTracker: eventsTracker,
                             secureDataStore: dataStore,
                             logHandler: logHandler)
    }
    
    // MARK: -
    
    public static var coreAPI: CoreAPI {
        guard let coreAPI = _shared?.coreAPI else {
            fatalError("Must configure ShopGunSDK with CoreAPI Settings")
        }
        return coreAPI
    }
    public static var hasCoreAPI: Bool {
        return _shared?.coreAPI != nil
    }
    
    // MARK: -
    
    public static var eventsTracker: EventsTracker {
        guard let eventsTracker = _shared?.eventsTracker else {
            fatalError("Must configure ShopGunSDK with EventsTracker Settings")
        }
        return eventsTracker
    }
    public static var hasEventsTracker: Bool {
        return _shared?.eventsTracker != nil
    }
    
    // MARK: -
    
    private static var _shared: ShopGunSDK?
    
    private init(coreAPI: CoreAPI?, eventsTracker: EventsTracker?, secureDataStore: ShopGunSDKSecureDataStore, logHandler: LogHandler?) {
        self.coreAPI = coreAPI
        self.eventsTracker = eventsTracker
        self.logHandler = logHandler
        self.secureDataStore = secureDataStore
    }
    
    private let coreAPI: CoreAPI?
    private let eventsTracker: EventsTracker?
    
    private let secureDataStore: ShopGunSDKSecureDataStore
    private let logHandler: LogHandler?
}

// MARK: -

private typealias ShopGunSDK_Logging = ShopGunSDK
extension ShopGunSDK_Logging {
    
    public enum LogLevel {
        case error
        case important
        case verbose
        case debug
    }
    
    public enum LogSource {
        case ShopGunSDK
        case CoreAPI
        case EventsTracker
        case GraphAPI
        case PagedPublicationViewer
        case other(name: String)
    }

    public static func log(_ message: String, level: LogLevel, source: LogSource, file: String = #file, function: String = #function, line: Int = #line) {
        
        guard let handler = _shared?.logHandler else { return }
        
        let sourceName: String
        switch source {
        case .ShopGunSDK:
            sourceName = "ShopGunSDK"
        case .CoreAPI:
            sourceName = "ShopGunSDK.CoreAPI"
        case .EventsTracker:
            sourceName = "ShopGunSDK.EventsTracker"
        case .GraphAPI:
            sourceName = "ShopGunSDK.GraphAPI"
        case .PagedPublicationViewer:
            sourceName = "ShopGunSDK.PagedPublicationViewer"
        case .other(let name):
            sourceName = "ShopGunSDK.\(name)"
        }
        
        handler("[\(sourceName)] \(message)", level, source, (file, function, line))
    }
}
