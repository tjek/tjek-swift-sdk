//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import TjekEventsTracker

@available(*, deprecated, message: "Use TjekEventsTracker instead.")
public final class EventsTracker {
    public typealias Context = TjekEventsTracker.Context
    
    public let settings: Settings.EventsTracker
    
    /// The `Context` that will be attached to all future events (at the moment of tracking).
    /// Modifying the context will only change events that are tracked in the future
    public var context: Context {
        get { actualTracker.context }
        set { actualTracker.context = newValue }
    }
    
    /// This will generate a new tokenizer with a new salt. Calling this will mean that any ViewToken sent with future events will not be connected to any historically shipped events.
    public func resetViewTokenizerSalt() {
        actualTracker.resetViewTokenizerSalt()
    }
    
    fileprivate let actualTracker: TjekEventsTracker
    fileprivate var notificationToken: NSObjectProtocol?
    
    internal init(settings: Settings.EventsTracker, dataStore: ShopGunSDKDataStore?) {
        let saltStore = SaltStore(
            get: { dataStore?.get(for: "ShopGunSDK.EventsTracker.ClientId") },
            set: { dataStore?.set(value: $0, for: "ShopGunSDK.EventsTracker.ClientId") }
        )
        
        let config = try! TjekEventsTracker.Config(trackId: .init(rawValue: settings.appId.rawValue), baseURL: settings.baseURL, dispatchInterval: settings.dispatchInterval, dispatchLimit: settings.dispatchLimit, enabled: settings.enabled)
        
        self.actualTracker = TjekEventsTracker(config: config, saltStore: saltStore)
        self.settings = settings
        
        self.notificationToken = NotificationCenter.default.addObserver(forName: TjekEventsTracker.didTrackEventNotification, object: actualTracker, queue: nil, using: { [weak self] in
            NotificationCenter.default.post(name: $0.name, object: self, userInfo: $0.userInfo)
        })
    }
    private init() { fatalError("You must provide settings when creating an EventsTracker") }
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
        actualTracker.trackEvent(event)
    }
}

// MARK: - Tracking Notifications

extension EventsTracker {
    
    /// The NotificationName for notifications posted when events are tracked. The Notification's userInfo contains the event. See `extractTrackedEvent(from:)` for an easy way to get the event from the Notification.
    public static let didTrackEventNotification = TjekEventsTracker.didTrackEventNotification
    
    /**
     Given a Notification triggered by the `didTrackEventNotification` with the name, this will look in the userInfo and return the `Event` object, if it exists. The result will be `nil` if the Notification is not of the correct kind, or userInfo doesnt contain an event.
     - parameter notification: The Notification to extract the `Event` from.
     */
    public static func extractTrackedEvent(from notification: Notification) -> Event? {
        TjekEventsTracker.extractTrackedEvent(from: notification)
    }
}

extension EventsTracker {
    /// The dateFormatter of all the dates in/out of the EventsTracker
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return formatter
    }()
}
