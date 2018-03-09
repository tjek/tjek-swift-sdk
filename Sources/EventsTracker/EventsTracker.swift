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
    public enum ClientIdentifierType {}
    public typealias ClientIdentifier = GenericIdentifier<ClientIdentifierType>
    public typealias EventType = String
    public typealias EventProperties = [String: AnyObject]
    
    public let settings: Settings.EventsTracker
    
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
        
        if settings.includeLocation {
            DispatchQueue.main.async {
                // Make sure we have a locationManager on first initialize (if needed).
                // This is because the CLLocationManager must be created on the main thread.
                _ = Context.LocationContext.location
            }
        }
        
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
        LifecycleEvents.clientSessionOpened.track(self)
        self.sessionLifecycleHandler.didStartNewSession = { [weak self] in
            guard let s = self else { return }
            LifecycleEvents.clientSessionOpened.track(s)
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
    
    public func trackEvent(_ type: EventType) {
        trackEvent(type, properties: nil)
    }
    
    public func trackEvent(_ type: EventType, properties: EventProperties?) {
        // make sure that all events are initially triggered on the main thread, to guarantee order.
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            
            s.trackEventSync(type, properties: properties)
        }
    }
    
    /// We expose this method internally so that the SDKConfig can enforce certain events being fired first.
    fileprivate func trackEventSync(_ type: EventType, properties: EventProperties?) {
        let event = ShippableEvent(type: type,
                                   trackId: settings.trackId,
                                   properties: properties,
                                   clientId: self.clientId.rawValue,
                                   includeLocation: settings.includeLocation)
        Logger.log("Event Tracked: '\(type)' \(properties ?? [:])", level: .debug, source: .EventsTracker)
        
        track(event: event)
    }
    
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
