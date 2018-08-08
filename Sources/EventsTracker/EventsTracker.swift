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
    
    public enum AppIdentiferType {}
    public typealias AppIdentifier = GenericIdentifier<AppIdentiferType>

    public struct Context {
        public var countryCode: String?
        public private(set) var location: (geohash: String, timestamp: Date)? = nil
        
        public mutating func updateLocation(latitude: Double, longitude: Double, timestamp: Date) {
            let hash = Geohash.encode(latitude: latitude, longitude: longitude, length: 4) // ±20km
            self.location = (hash, timestamp)
        }
    }
    
    public let settings: Settings.EventsTracker
    
    /// The `Context` that will be attached to all future events (at the moment of tracking).
    /// Modifying the context will only change events that are tracked in the future
    public var context: Context = Context()

    internal init(settings: Settings.EventsTracker, dataStore: ShopGunSDKDataStore?) {
        self.settings = settings
        self.dataStore = dataStore
        
        let eventsShipper = EventsShipper_v1(baseURL: settings.baseURL, dryRun: settings.enabled == false)
        let eventsCache = EventsCache_v1(fileName: "com.shopgun.ios.sdk.events_pool.disk_cache.plist")
        
        self.pool = CachedFlushablePool(dispatchInterval: settings.dispatchInterval,
                                        dispatchLimit: settings.dispatchLimit,
                                        shipper: eventsShipper,
                                        cache: eventsCache)
        
        // Make sure we've cleaned up any legacy data that is no longer needed
        EventsTracker.clearUnusedLegacyData(from: dataStore)
        
        // Assign the callback for the session handler.
        // Note that the eventy must be triggered manually first time.
        self.trackEvent(Event.clientSessionOpened())
        self.sessionLifecycleHandler.didStartNewSession = { [weak self] in
            self?.trackEvent(Event.clientSessionOpened())
        }
    }
    private init() { fatalError("You must provide settings when creating an EventsTracker") }
    
    private weak var dataStore: ShopGunSDKDataStore?

    fileprivate let pool: CachedFlushablePool
    
    private let sessionLifecycleHandler = SessionLifecycleHandler()
}

// MARK: -

extension EventsTracker {
    fileprivate static var _shared: EventsTracker?
    
    public static var shared: EventsTracker {
        guard let eventsTracker = _shared else {
            fatalError("Must call `EventsTracker.configure(…)` before accessing `shared`")
        }
        return eventsTracker
    }
    
    public static var isConfigured: Bool {
        return _shared != nil
    }
    
    /// This will cause a fatalError if KeychainDataStore hasnt been configured
    public static func configure() {
        do {
            guard let settings = try Settings.loadShared().eventsTracker else {
                fatalError("Required EventsTracker settings missing from '\(Settings.defaultSettingsFileName)'")
            }
            
            configure(settings)
        } catch let error {
            fatalError(String(describing: error))
        }
    }
    
    /// This will cause a fatalError if KeychainDataStore hasnt been configured
    public static func configure(_ settings: Settings.EventsTracker, dataStore: ShopGunSDKDataStore = KeychainDataStore.shared) {
        
        if isConfigured {
            Logger.log("Re-configuring", level: .verbose, source: .EventsTracker)
        } else {
            Logger.log("Configuring", level: .verbose, source: .EventsTracker)
        }
        
        _shared = EventsTracker(settings: settings, dataStore: dataStore)
    }
}

// MARK: - Tracking methods

extension EventsTracker {
    
    public func trackEvent(_ event: Event) {
        
        // TODO: Do on shared queue?
        
        // Mark the event with the tracker's context & appId
        let eventToTrack = event
            .addingAppIdentifier(AppIdentifier(rawValue: self.settings.appId))
            .addingContext(self.context)
        
        Logger.log("Event Tracked: '\(event)'", level: .debug, source: .EventsTracker)
        
        // push the event to the cached pool
//        self.pool.push(object: event)
        
        // send a notification for that specific event, a generic one
//        NotificationCenter.default.post(name: .eventTracked(type: event.type), object: self, userInfo: eventInfo)
//        NotificationCenter.default.post(name: .eventTracked(), object: self, userInfo: eventInfo)
    }
}
