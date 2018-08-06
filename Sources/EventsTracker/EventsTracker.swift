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
    
    public enum ClientIdentifierType {}
    public typealias ClientIdentifier = GenericIdentifier<ClientIdentifierType>
    public typealias EventType = String
    public typealias EventProperties = [String: AnyObject]
    
    public let settings: Settings.EventsTracker
    
    /// The `Context` that will be attached to all future events (at the moment of tracking).
    /// Modifying the context will only change events that are tracked in the future
    public var context: Context = Context()
    
    private weak var dataStore: ShopGunSDKDataStore?

    internal init(settings: Settings.EventsTracker, dataStore: ShopGunSDKDataStore?) {
        self.settings = settings
        self.dataStore = dataStore
        
        let eventsShipper = EventsShipper(baseURL: settings.baseURL, dryRun: settings.enabled == false)
        let eventsCache = EventsCache(fileName: "com.shopgun.ios.sdk.events_pool.disk_cache.plist")
        
        self.pool = CachedFlushablePool(dispatchInterval: settings.dispatchInterval,
                                        dispatchLimit: settings.dispatchLimit,
                                        shipper: eventsShipper,
                                        cache: eventsCache)
        
        self.sessionLifecycleHandler = SessionLifecycleHandler()
        
        // Try to get the stored clientId, migrate the legacy clientId, or generate a new one.
        if let storedClientId = EventsTracker.loadClientId(from: dataStore) {
            self.clientId = storedClientId
        } else {
            if let legacyClientId = EventsTracker.loadLegacyClientId() {
                self.clientId = legacyClientId
                EventsTracker.clearLegacyClientId()
                Logger.log("Loaded ClientId from Legacy cache", level: .debug, source: .EventsTracker)
            } else {
                self.clientId = ClientIdentifier.generate()

                // A new clientId was generated, so send an event
                LifecycleEvents.firstClientSessionOpened.track(self)
            }
            
            // Save the new clientId back to the store
            EventsTracker.updateDataStore(dataStore, clientId: self.clientId)
        }
        
        // Assign the callback for the session handler.
        // Note that the eventy must be triggered manually first time.
        self.trackEvent(Event.clientSessionOpened())
        self.sessionLifecycleHandler.didStartNewSession = { [weak self] in
            self?.trackEvent(Event.clientSessionOpened())
        }
    }
    private init() { fatalError("You must provide settings when creating an EventsTracker") }

    fileprivate let pool: CachedFlushablePool
    
    public private(set) var clientId: ClientIdentifier
    
    public func resetClientId() {
        self.clientId = ClientIdentifier.generate()
        EventsTracker.updateDataStore(self.dataStore, clientId: self.clientId)
        
        LifecycleEvents.firstClientSessionOpened.track(self)
        
        LifecycleEvents.clientSessionOpened.track(self)
    }
    
    fileprivate let sessionLifecycleHandler: SessionLifecycleHandler
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

extension EventsTracker {
    
    @available(*, deprecated)
    public func trackEvent(_ type: EventType) {
        trackEvent(type, properties: nil)
    }
    
    @available(*, deprecated)
    public func trackEvent(_ type: EventType, properties: EventProperties?) {
        // make sure that all events are initially triggered on the main thread, to guarantee order.
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            
            s.trackEventSync(type, properties: properties)
        }
    }
    
    /// We expose this method internally so that the SDKConfig can enforce certain events being fired first.
    @available(*, deprecated)
    fileprivate func trackEventSync(_ type: EventType, properties: EventProperties?) {
        let event = ShippableEvent(type: type,
                                   trackId: settings.appId,
                                   properties: properties,
                                   clientId: self.clientId.rawValue,
                                   includeLocation: false)
        Logger.log("Event Tracked: '\(type)' \(properties ?? [:])", level: .debug, source: .EventsTracker)
        
        track(event: event)
    }
    
    @available(*, deprecated)
    fileprivate func track(event: EventsTracker.ShippableEvent) {
        
        self.pool.push(object: event)
        
        // save the eventInfo into a dict for sending as a notification
        var eventInfo: [String: AnyObject] = ["type": event.type as AnyObject,
                                              "uuid": event.uuid as AnyObject]
        if event.properties != nil {
            eventInfo["properties"] = event.properties! as AnyObject
        }
        
        // send a notification for that specific event, a generic one
        NotificationCenter.default.post(name: .eventTracked(type: event.type), object: self, userInfo: eventInfo)
        NotificationCenter.default.post(name: .eventTracked(), object: self, userInfo: eventInfo)
    }
    
}

// MARK: - Lifecycle events

extension EventsTracker {
    
    @available(*, deprecated)
    fileprivate enum LifecycleEvents {
        case firstClientSessionOpened
        case clientSessionOpened
        
        var type: EventType {
            switch self {
            case .firstClientSessionOpened:
                return "first-client-session-opened"
            case .clientSessionOpened:
                return "client-session-opened"
            }
        }
        var properties: EventProperties {
            return [:]
        }
        
        func track(_ tracker: EventsTracker) {
            tracker.trackEvent(self.type, properties: self.properties)
        }
    }
}
