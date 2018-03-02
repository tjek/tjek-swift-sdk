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
            eventsTracker = EventsTracker(settings: eventsTrackerSettings, secureDataStore: dataStore)
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
     The signature of a function that can handle log messages sent from the ShopGun SDK.
     Users of the SDK can define a function that conforms to this signature and pass it into the `configure` function.
     - parameter message: The log message generated by the SDK
     - parameter level: What 'kind/severity' this log represents. Could be used for filtering. See `LogLevel`.
     - parameter source: What part of the SDK triggered this message. Could be used for filtering. See `LogSource`.
     - parameter location: Where (file/line/function) in the SDK this message was triggered. See `LogLocation`.
     */
    public typealias LogHandler = (_ message: String, _ level: LogLevel, _ source: LogSource, _ location: LogLocation) -> Void
    
    /**
     When logging a message, this defines its 'type' or 'severity'. It is important to pick the correct LogLevel for the type of message that is being logged.
     
     The LogLevel can be used by the `LogHandler` to filter messages that are too verbose or not of interest, or to change how the message is printed to the console (eg. prefix an emoji)
     */
    public enum LogLevel {
        /// Critical errors within the SDK (eg. unable to complete a request).
        case error
        /// Anything that isnt an error, but should be seen by the developer (eg. unable to do something, so a fallback was triggered).
        case important
        /// Other logs that aren't important, but might be of interest (eg. request completed successfully)
        case verbose
        /// For logs whose purpose is solely for debugging the SDK. Probably only relevant while in the process of developing a feature.
        case debug
        /// For logs that contain performance analytics (eg. request completion time)
        case performance
        
        /// The `LogLevel`s that should probably be always logged (`error` & `important`). This can be used as a filter by the `LogHandler`
        public static var criticalLevels: [LogLevel] = [.error, important]
        /// All the `LogLevel`s
        public static var allLevels: [LogLevel] = [.error, important, .verbose, .debug, .performance]
    }
    
    /**
     All the possible components of the SDK that can trigger a log.
     
     When logging a message it is important to define which 'part' of the SDK the log came from. This way the `LogHandler` can filter out messages from parts of the SDK it is not interested in, or change how it prints the message.
     */
    public enum LogSource {
        /// The main part of the SDK - so not from any specific component.
        case ShopGunSDK
        /// A message from the CoreAPI component (which talks to the ShopGun API).
        case CoreAPI
        /// A message from the EventsTracker component (which caches/sends events to the ShopGun server).
        case EventsTracker
        /// A message from the GraphAPI component (which talks to the ShopGun Graph API).
        case GraphAPI
        /// A message from the PagedPublication view (which renders an interactive catalog).
        case PagedPublicationViewer
        /// In case none of the above are relevant, the LogSource can provide its own `name` (for example if someone outside the SDK wishes to log via the `LogHandler`).
        case other(name: String)
        
        fileprivate var sourceName: String {
            switch self {
            case .ShopGunSDK:
                return "ShopGunSDK"
            case .CoreAPI:
                return "ShopGunSDK.CoreAPI"
            case .EventsTracker:
                return "ShopGunSDK.EventsTracker"
            case .GraphAPI:
                return "ShopGunSDK.GraphAPI"
            case .PagedPublicationViewer:
                return "ShopGunSDK.PagedPublicationViewer"
            case .other(let name):
                return "ShopGunSDK.\(name)"
            }
        }
    }

    /**
     Defines the location (path/function/line) from which a log was called.
     */
    public struct LogLocation {
        /// The file path of where a log was triggered.
        public let filePath: String
        /// The name of the function where a log was triggered.
        public let functionName: String
        /// The linenumber within `filePath` where a log was triggered.
        public let lineNumber: Int
        
        /// A shortcut for getting the last component of the `filePath`.
        public var fileName: String {
            return filePath.components(separatedBy: "/").last ?? filePath
        }
    }
    
    /**
     Forwards a message to the LogHandler that was provided in the `configure(settings:logHandler:)` function. Prefixes the message with a 'source name' (eg. "[ShopGunSDK.CoreAPI]", based on the provided `LogSource`.
     - parameter message: The message to send to the LogHandler.
     - parameter level: What 'kind/severity' this log represents. See `LogLevel`.
     - parameter source: What part of the SDK triggered this message. See `LogSource`.
     - parameter file: The path to the file in which this log function was called. If omitted it will default to the call-site filepath (`#file`).
     - parameter function: The name of the function in which this log function was called. If omitted it will default to the call-site function name (`#function`).
     - parameter line: The line number in the file in which this log function was called. If omitted it will  default to the call-site line number (`#line`).
     */
    public static func log(_ message: String, level: LogLevel, source: LogSource, file: String = #file, function: String = #function, line: Int = #line) {
        
        guard let handler = _logHandler else { return }
        
        let sourceName = source.sourceName
        
        handler("[\(sourceName)] \(message)", level, source, LogLocation(filePath: file, functionName: function, lineNumber: line))
    }
}
