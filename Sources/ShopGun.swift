//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

/**
 This is the namespace for configuring and accessing the static components of ther Shopgun SDK.
 It cannot be instantiated - all access is via the static functions & variables.
 
 The ShopGun SDK consists of a number of components (eg. `CoreAPI`, `EventsTracker` etc). They are accessed via the static variables (eg. `ShopGun.coreAPI`, `ShopGun.eventsTracker` etc).
 
 Before you access any component it must be configured by including it's settings when calling the static function `ShopGun.configure(settings:logHandler:)`.
 
 If you try to access a component whose settings havn't been included in the settings passed to the configure method, a `fatalError` will be triggered.
 */
public final class ShopGun {
    
    private static var _shared: ShopGun?
    private static var _logHandler: LogHandler?
    
    private init(coreAPI: CoreAPI?, eventsTracker: EventsTracker?, graphAPI: GraphAPI?, secureDataStore: ShopGunSDKSecureDataStore) {
        self.coreAPI = coreAPI
        self.eventsTracker = eventsTracker
        self.graphAPI = graphAPI
        self.secureDataStore = secureDataStore
    }

    private let coreAPI: CoreAPI?
    private let eventsTracker: EventsTracker?
    private let graphAPI: GraphAPI?
    
    private let secureDataStore: ShopGunSDKSecureDataStore
}

extension ShopGun {
    
    // MARK: - Configuration
    
    public struct Settings {
        public var coreAPI: CoreAPI.Settings?
        public var eventsTracker: EventsTracker.Settings?
        public var graphAPI: GraphAPI.Settings?
        
        // if this is set then secure data will available to other apps (check entitlements)
        public var sharedKeychainGroupId: String?
        
        public init(coreAPI: CoreAPI.Settings?, eventsTracker: EventsTracker.Settings?, graphAPI: GraphAPI.Settings?, sharedKeychainGroupId: String? = nil) {
            self.coreAPI = coreAPI
            self.eventsTracker = eventsTracker
            self.graphAPI = graphAPI
            self.sharedKeychainGroupId = sharedKeychainGroupId
        }
        
        // TODO: need a way to get default settings from a .plist file
    }
    
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
        
        // configure the GraphAPI, if settings provided
        var graphAPI: GraphAPI? = nil
        if let graphAPISettings = settings.graphAPI {
            ShopGun.log("Configuring GraphAPI", level: .verbose, source: .ShopGunSDK)
            graphAPI = GraphAPI(settings: graphAPISettings)
        }
        
        _shared = ShopGun(coreAPI: coreAPI,
                          eventsTracker: eventsTracker,
                          graphAPI: graphAPI,
                          secureDataStore: dataStore)
    }
}


extension ShopGun {
    
    // MARK: - Components
    
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
    
    public static var graphAPI: GraphAPI {
        guard let graphAPI = _shared?.graphAPI else {
            fatalError("Must configure ShopGunSDK with GraphAPI Settings")
        }
        return graphAPI
    }
    public static var hasGraphAPI: Bool {
        return _shared?.graphAPI != nil
    }
}

extension ShopGun {
    
    // MARK: - Logging

    /**
     The structure of a function that can handle log messages sent from the ShopGun SDK.
     Users of the SDK can define a function that conforms to this signature and pass it into the `configure` function.
     - parameter message: The log message generated by the SDK
     - parameter level: What 'kind/severity' this log represents. Could be used for filtering. See `LogLevel`.
     - parameter source: What part of the SDK triggered this message. Could be used for filtering. See `LogSource`.
     - parameter location: Where (file/line/function) in the SDK this message was triggered. See `LogLocation`.
     */
    public typealias LogHandler = (_ message: String, _ level: LogLevel, _ source: LogSource, _ location: LogLocation) -> Void
    
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
