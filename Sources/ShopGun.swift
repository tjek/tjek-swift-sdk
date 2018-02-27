//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public struct ShopGun {
    
    public typealias LogHandler = (_ message: String, _ level: LogLevel, _ source: LogSource, _ location: LogLocation) -> Void
    
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
        
        _logHandler = logHandler
        
        // configure the shared DataStore
        let dataStore: ShopGunSDKSecureDataStore
        if ShopGun.isRunningInPlayground {
            dataStore = PlaygroundDataStore()
        } else {
            dataStore = KeychainDataStore(sharedKeychainGroupId: settings.sharedKeychainGroupId)
        }
        
        // configure the CoreAPI, if settings provided
        var coreAPI: CoreAPI? = nil
        if let coreAPISettings = settings.coreAPI {
            ShopGun.log("Configuring CoreAPI", level: .verbose, source: .ShopGunSDK)
            coreAPI = CoreAPI(settings: coreAPISettings, secureDataStore: dataStore)
        }
        
        // configure the EventsTracker, if settings provided
        var eventsTracker: EventsTracker? = nil
        if let eventsTrackerSettings = settings.eventsTracker {
            ShopGun.log("Configuring EventsTracker", level: .verbose, source: .ShopGunSDK)
            eventsTracker = EventsTracker(settings: eventsTrackerSettings)
        }
        
        // TODO: configure the GraphAPI, if settings provided
        
        _shared = ShopGun(coreAPI: coreAPI,
                          eventsTracker: eventsTracker,
                          secureDataStore: dataStore)
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
    
    private static var _shared: ShopGun?
    private static var _logHandler: LogHandler?
    
    private init(coreAPI: CoreAPI?, eventsTracker: EventsTracker?, secureDataStore: ShopGunSDKSecureDataStore) {
        self.coreAPI = coreAPI
        self.eventsTracker = eventsTracker
        self.secureDataStore = secureDataStore
    }
    
    private let coreAPI: CoreAPI?
    private let eventsTracker: EventsTracker?
    
    private let secureDataStore: ShopGunSDKSecureDataStore
    
}

// MARK: -

private typealias ShopGunSDK_Logging = ShopGun
extension ShopGunSDK_Logging {
    
    public enum LogLevel {
        case error
        case important
        case verbose
        case debug
        case performance
        
        public static var criticalLevels: [LogLevel] = [.error, important]
        public static var allLevels: [LogLevel] = [.error, important, .verbose, .debug, .performance]
    }
    
    public enum LogSource {
        case ShopGunSDK
        case CoreAPI
        case EventsTracker
        case GraphAPI
        case PagedPublicationViewer
        case other(name: String)
    }

    public struct LogLocation {
        public let filePath: String
        public let functionName: String
        public let lineNumber: Int
        
        public var fileName: String {
            return filePath.components(separatedBy: "/").last ?? filePath
        }
    }
    
    public static func log(_ message: String, level: LogLevel, source: LogSource, file: String = #file, function: String = #function, line: Int = #line) {
        
        guard let handler = _logHandler else { return }
        
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
        
        handler("[\(sourceName)] \(message)", level, source, LogLocation(filePath: file, functionName: function, lineNumber: line))
    }
}
