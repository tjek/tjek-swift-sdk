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
    public typealias PersonId = CoreAPI.Person.Identifier
    public typealias EventType = String
    public typealias EventProperties = [String: AnyObject]

    public struct Settings {
        public var trackId: String
        public var baseURL: URL
        public var dispatchInterval: TimeInterval
        public var dispatchLimit: Int
        public var dryRun: Bool
        public var includeLocation: Bool
        
        public init(trackId: String, baseURL: URL = URL(string: "https://events.service.shopgun.com")!, dispatchInterval: TimeInterval = 120.0, dispatchLimit: Int = 100, dryRun: Bool = false, includeLocation: Bool = false) {
            self.trackId = trackId
            self.baseURL = baseURL
            self.dispatchInterval = dispatchInterval
            self.dispatchLimit = dispatchLimit
            self.dryRun = dryRun
            self.includeLocation = includeLocation
        }
    }
    
    public let settings: Settings
    
    private weak var secureDataStore: ShopGunSDKSecureDataStore?

    internal init(settings: Settings, secureDataStore: ShopGunSDKSecureDataStore?) {
        self.settings = settings
        self.secureDataStore = secureDataStore
        
        let eventsShipper = EventsShipper(baseURL: settings.baseURL, dryRun: settings.dryRun)
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
        if let storedClientId = EventsTracker.loadClientId(from: secureDataStore) {
            self.clientId = storedClientId
        } else {
            if let legacyClientId = EventsTracker.loadLegacyClientId() {
                self.clientId = legacyClientId
                EventsTracker.clearLegacyClientId()
                ShopGun.log("Loaded ClientId from Legacy cache", level: .debug, source: .EventsTracker)
            } else {
                self.clientId = ClientIdentifier.generate()

                // A new clientId was generated, so send an event
                LifecycleEvents.firstClientSessionOpened.track(self)
            }
            
            // Save the new clientId back to the store
            EventsTracker.updateDataStore(secureDataStore, clientId: self.clientId)
        }
        
        // Assign the callback for the session handler.
        // Note that the eventy must be triggered manually first time.
        LifecycleEvents.clientSessionOpened.track(self)
        self.sessionLifecycleHandler.didStartNewSession = { [weak self] in
            guard let s = self else { return }
            LifecycleEvents.clientSessionOpened.track(s)
        }
    }
    
    fileprivate let pool: CachedFlushablePool
    
    public private(set) var clientId: ClientIdentifier
    
    public func resetClientId() {
        self.clientId = ClientIdentifier.generate()
        EventsTracker.updateDataStore(self.secureDataStore, clientId: self.clientId)
        
        LifecycleEvents.firstClientSessionOpened.track(self)
        
        LifecycleEvents.clientSessionOpened.track(self)
    }
    
    fileprivate let sessionLifecycleHandler: SessionLifecycleHandler
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
        ShopGun.log("Event Tracked: '\(type)' \(properties ?? [:])", level: .debug, source: .EventsTracker)
        
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
