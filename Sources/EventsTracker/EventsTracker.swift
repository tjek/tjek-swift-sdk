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
        // TODO: Share location property, default to false
        
        public init(trackId: String, baseURL: URL, dispatchInterval: TimeInterval, dispatchLimit: Int, dryRun: Bool) {
            self.trackId = trackId
            self.baseURL = baseURL
            self.dispatchInterval = dispatchInterval
            self.dispatchLimit = dispatchLimit
            self.dryRun = dryRun
        }

    }
    
    public let settings: Settings
    
    internal init(settings: Settings) {
        self.settings = settings
        
        let eventsShipper = EventsShipper(baseURL: settings.baseURL, dryRun: settings.dryRun)
        let eventsCache = EventsCache(fileName: "com.shopgun.ios.sdk.events_pool.disk_cache.plist")
        
        self.pool = CachedFlushablePool(dispatchInterval: settings.dispatchInterval,
                                        dispatchLimit: settings.dispatchLimit,
                                        shipper: eventsShipper,
                                        cache: eventsCache)
    }
    
    fileprivate let pool: CachedFlushablePool
    
    // MARK: - User Context
    
    /// The optional PersonId that will be sent with every event
    public var personId: PersonId? {
        didSet {
            ShopGun.log("personId Updated '\(personId?.rawValue ?? "-")'", level: .debug, source: .EventsTracker)
        }
    }
    
    // MARK: - View Context
    
    /// Allows the client to attach view information to all future events.
    public func updateView(_ path: [String]? = nil, uri: String? = nil, previousPath: [String]? = nil) {
        DispatchQueue.main.async { [weak self] in
            ShopGun.log("ViewContext Updated '\(path?.joined(separator: ".") ?? "")' (was '\(previousPath?.joined(separator: ".") ?? "")') \(uri ?? "")", level: .debug, source: .EventsTracker)
            
            if path == nil && previousPath == nil && uri == nil {
                self?._currentViewContext = nil
            } else {
                self?._currentViewContext = Context.ViewContext(path: path, previousPath: previousPath, uri: uri)
            }
        }
        
    }
    fileprivate var _currentViewContext: Context.ViewContext?
    
    // MARK: - Campaign Context
    
    /// Allows the client to attach campaign information to all future events
    public func updateCampaign(name: String? = nil, source: String? = nil, medium: String? = nil, term: String? = nil, content: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            if name == nil && source == nil && medium == nil && term == nil && content == nil {
                self?._currentCampaignContext = nil
            } else {
                self?._currentCampaignContext = Context.CampaignContext(name: name, source: source, medium: medium, term: term, content: content)
            }
        }
    }
    fileprivate var _currentCampaignContext: Context.CampaignContext?
}

extension EventsTracker.Settings {
    public static func `default`(trackId: String) -> EventsTracker.Settings {
        return .init(trackId: trackId, baseURL: URL(string: "https://events.service.shopgun.com")!, dispatchInterval: 120, dispatchLimit: 100, dryRun: false)
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
        let clientId = "foo"
        let sessionId = "bar"
        
        let event = ShippableEvent(type: type,
                                   trackId: settings.trackId,
                                   properties: properties,
                                   clientId: clientId,
                                   sessionId: sessionId,
                                   personId: IdField.legacy(personId?.rawValue),
                                   viewContext: _currentViewContext,
                                   campaignContext: _currentCampaignContext)
        ShopGun.log("Event Tracked: '\(type)' \(properties ?? [:])", level: .debug, source: .EventsTracker)
        
        track(event: event)
    }
    
    fileprivate func track(event: EventsTracker.ShippableEvent) {
        
        self.pool.push(object: event)
        
        var eventInfo: [String: AnyObject] = ["type": event.type as AnyObject,
                                              "uuid": event.uuid as AnyObject]
        if event.properties != nil {
            eventInfo["properties"] = event.properties! as AnyObject
        }
        
        if let viewDict = event.viewContext?.toDictionary() {
            eventInfo["view"] = viewDict as AnyObject
        }
        
        if let personId = event.personId?.id {
            eventInfo["personId"] = personId as AnyObject
        }
        
        // send a notification for that specific event, a generic one
        NotificationCenter.default.post(name: .eventTracked(type: event.type), object: self, userInfo: eventInfo)
        NotificationCenter.default.post(name: .eventTracked(), object: self, userInfo: eventInfo)
    }
    
}
