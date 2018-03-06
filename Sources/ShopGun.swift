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
 
 Before you access any component it must be configured by including it's settings when calling the static function `ShopGun.configure(settings:)`.
 
 If you try to access a component whose settings havn't been included in the settings passed to the configure method, a `fatalError` will be triggered.
 */
public final class ShopGun {

    private static var _shared: ShopGun?
    private init(coreAPI: CoreAPI?, eventsTracker: EventsTracker?, graphAPI: GraphAPI?) {
        self.coreAPI = coreAPI
        self.eventsTracker = eventsTracker
        self.graphAPI = graphAPI
    }

    private let coreAPI: CoreAPI?
    private let eventsTracker: EventsTracker?
    private let graphAPI: GraphAPI?
}

extension ShopGun {
    
    // MARK: - Configuration
    
    public struct Settings {
        public var coreAPI: CoreAPI.Settings?
        public var eventsTracker: EventsTracker.Settings?
        public var graphAPI: GraphAPI.Settings?

        public init(coreAPI: CoreAPI.Settings?, eventsTracker: EventsTracker.Settings?, graphAPI: GraphAPI.Settings?, sharedKeychainGroupId: String? = nil) {
            self.coreAPI = coreAPI
            self.eventsTracker = eventsTracker
            self.graphAPI = graphAPI
        }
        
        // TODO: need a way to get default settings from a .plist file
    }
    
    public static func configure(settings: Settings) {
        
        // configure the shared DataStore
        let dataStore: ShopGunSDKDataStore
        if ShopGun.isRunningInPlayground {
            dataStore = PlaygroundDataStore()
        } else {
            dataStore = KeychainDataStore.shared
        }
        
        // configure the CoreAPI, if settings provided
        var coreAPI: CoreAPI? = nil
        if let coreAPISettings = settings.coreAPI {
            Logger.log("Configuring CoreAPI", level: .verbose, source: .ShopGunSDK)
            coreAPI = CoreAPI(settings: coreAPISettings, dataStore: dataStore)
        }
        
        // configure the EventsTracker, if settings provided
        var eventsTracker: EventsTracker? = nil
        if let eventsTrackerSettings = settings.eventsTracker {
            Logger.log("Configuring EventsTracker", level: .verbose, source: .ShopGunSDK)
            eventsTracker = EventsTracker(settings: eventsTrackerSettings, dataStore: dataStore)
        }
        
        // configure the GraphAPI, if settings provided
        var graphAPI: GraphAPI? = nil
        if let graphAPISettings = settings.graphAPI {
            Logger.log("Configuring GraphAPI", level: .verbose, source: .ShopGunSDK)
            graphAPI = GraphAPI(settings: graphAPISettings)
        }
        
        _shared = ShopGun(coreAPI: coreAPI,
                          eventsTracker: eventsTracker,
                          graphAPI: graphAPI)
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
