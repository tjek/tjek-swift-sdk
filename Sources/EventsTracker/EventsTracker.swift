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
    
    internal init(settings: Settings) {
        self.settings = settings
        
        if settings.includeLocation {
            DispatchQueue.main.async {
                // Make sure we have a locationManager on first initialize (if needed).
                // This is because the CLLocationManager must be created on the main thread.
                _ = Context.LocationContext.location
            }
        }
        
        let eventsShipper = EventsShipper(baseURL: settings.baseURL, dryRun: settings.dryRun)
        let eventsCache = EventsCache(fileName: "com.shopgun.ios.sdk.events_pool.disk_cache.plist")
        
        self.pool = CachedFlushablePool(dispatchInterval: settings.dispatchInterval,
                                        dispatchLimit: settings.dispatchLimit,
                                        shipper: eventsShipper,
                                        cache: eventsCache)
    }
    
    fileprivate let pool: CachedFlushablePool
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
        let clientId = "foo" //TODO: REAL ClientId
        
        let event = ShippableEvent(type: type,
                                   trackId: settings.trackId,
                                   properties: properties,
                                   clientId: clientId,
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
