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
    
    public struct Context {
        /**
         The location information of the app's user. Once set, this will be sent with all future tracked events.
         - A geohash of the location (this will have an accuracy no-greater than ±20km)
         - The timestamp of when that location info was collected.
         
         It is up to you to collect this info from the user. See the `updateLocation(latitude:longitude:timestamp:)` method.
         */
        public private(set) var location: (geohash: String, timestamp: Date)? = nil
        
        /**
         Updates the `location` property, using a lat/lng/timestamp to generate the geohash (to an accuracy of ±20km). This geohash will be included in all _future_ tracked events, until `clearLocation()` is called.
         - Note: It is up to the user of the SDK to decide how this location information is collected. We recommend, however, that only GPS-sourced location data is used.
         - parameter latitude: The latitide to use when generating the `location`'s geohash.
         - parameter longitude: The longitude to use when generating the `location`'s geohash.
         - parameter timestamp: The date that the lat/lng pair was generated (eg. when the user was discovered to be at that location)
         */
        public mutating func updateLocation(latitude: Double, longitude: Double, timestamp: Date) {
            let hash = Geohash.encode(latitude: latitude, longitude: longitude, length: 4) // ±20km
            self.location = (hash, timestamp)
        }
        
        /**
         After this is called, the `location` geohash/timestamp will be set to `nil` and no longer sent with future tracked events.
        */
        public mutating func clearLocation() {
            self.location = nil
        }
    }
    
    public let settings: Settings.EventsTracker
    
    /// The `Context` that will be attached to all future events (at the moment of tracking).
    /// Modifying the context will only change events that are tracked in the future
    public var context: Context = Context()

    internal var viewTokenizer: UniqueViewTokenizer
    
    /// This will generate a new tokenizer with a new salt. Calling this will mean that any ViewToken sent with future events will not be connected to any historically shipped events.
    public func resetViewTokenizerSalt() {
        self.viewTokenizer = UniqueViewTokenizer.reload(from: dataStore)
    }
    
    internal init(settings: Settings.EventsTracker, dataStore: ShopGunSDKDataStore?) {
        self.settings = settings
        self.dataStore = dataStore
        self.viewTokenizer = UniqueViewTokenizer.load(from: dataStore)

        let eventsShipper = EventsShipper(baseURL: settings.baseURL, dryRun: settings.enabled == false, appContext: .init(id: settings.appId))
        let eventsCache = EventsCache<ShippableEvent>(fileName: "com.shopgun.ios.sdk.events_pool.disk_cache.v2.plist")
        
        self.pool = EventsPool(dispatchInterval: settings.dispatchInterval,
                               dispatchLimit: settings.dispatchLimit,
                               shippingHandler: eventsShipper.ship,
                               cache: eventsCache)
        
        EventsTracker.legacyPoolCleaner(baseURL: settings.baseURL, enabled: settings.enabled) { (cleanedEvents) in
            Logger.log("LegacyEventsPool cleaned (\(cleanedEvents) events)", level: .debug, source: .EventsTracker)
        }
    }
    private init() { fatalError("You must provide settings when creating an EventsTracker") }
    
    private weak var dataStore: ShopGunSDKDataStore?

    fileprivate let pool: EventsPool
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
            .addingAppIdentifier(self.settings.appId)
            .addingContext(self.context)
        
        // push the event to the cached pool
        guard let shippableEvent = ShippableEvent(event: eventToTrack) else { return }
        
        self.pool.push(event: shippableEvent)
        
        let eventInfo = [EventsTracker.trackedEventNotificationKey: eventToTrack]
        
        Logger.log("📩 Event Tracked: \(shippableEvent)", level: .debug, source: .EventsTracker)
        
        // send a notification
        NotificationCenter.default.post(name: EventsTracker.didTrackEventNotification,
                                        object: self,
                                        userInfo: eventInfo)
    }
}

// MARK: - Tracking Notifications

extension EventsTracker {
    
    /// The NotificationName for notifications posted when events are tracked. The Notification's userInfo contains the event. See `extractTrackedEvent(from:)` for an easy way to get the event from the Notification.
    public static let didTrackEventNotification = Notification.Name(rawValue: "ShopGunSDK.EventsTracker.eventTracked")
    
    /// The key to access the event in the `didTrackEventNotification` notification's userInfo dictionary.
    fileprivate static let trackedEventNotificationKey = "trackedEvent"
    
    /**
     Given a Notification triggered by the `didTrackEventNotification` with the name, this will look in the userInfo and return the `Event` object, if it exists. The result will be `nil` if the Notification is not of the correct kind, or userInfo doesnt contain an event.
     - parameter notification: The Notification to extract the `Event` from.
     */
    public static func extractTrackedEvent(from notification: Notification) -> Event? {
        guard notification.name == EventsTracker.didTrackEventNotification else {
            return nil
        }
        
        return notification.userInfo?[EventsTracker.trackedEventNotificationKey] as? Event
    }
}
