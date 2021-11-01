///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation
import TjekUtils

public class TjekEventsTracker {
    
    public struct Config: Equatable {
        public enum AppIdentiferTag {}
        public typealias AppIdentifier = GenericIdentifier<AppIdentiferTag>
        
        public var appId: AppIdentifier
        
        public var baseURL: URL
        public var dispatchInterval: TimeInterval
        public var dispatchLimit: Int
        public var enabled: Bool
        
        public init(appId: AppIdentifier, baseURL: URL = URL(string: "https://wolf-api.tjek.com")!, dispatchInterval: TimeInterval = 120.0, dispatchLimit: Int = 100, enabled: Bool = true) throws {
            
            guard !appId.rawValue.isEmpty else {
                struct AppIdEmpty: Error { }
                throw AppIdEmpty()
            }
            
            self.appId = appId
            self.baseURL = baseURL
            self.dispatchInterval = dispatchInterval
            self.dispatchLimit = dispatchLimit
            self.enabled = enabled
        }
    }
    
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
    
    /// Initialize the `shared` TjekEventsTracker using the specified `Config`.
    public static func initialize(config: Config, saltStore: SaltStore = .keychain(KeychainDataStore(config: .privateKeychain(id: nil)))) {
        _shared = TjekEventsTracker(config: config, saltStore: saltStore)
    }
    /**
     Initialize the `shared` TjekEventsTracker using the config plist file.
     Config file should be placed in your main bundle, with the name `TjekSDK-Config.plist`.
     
     Its contents should map to the following dictionary:
     `["EventsTracker": ["appId": "<your appId>"]]`
     
     - Note: Throws if the config file is missing or malformed.
     */
    public static func initialize() throws {
        let config = try Config.loadFromPlist()
        let keychainConfig = (try? KeychainDataStore.Config.loadFromPlist()) ?? .privateKeychain(id: nil)
        initialize(config: config, saltStore: .keychain(KeychainDataStore(config: keychainConfig)))
    }
    
    private static var _shared: TjekEventsTracker!
    
    /// Do not reference this instance of the TjekEventsTracker until you have called one of the static `initialize` functions.
    public static var shared: TjekEventsTracker {
        guard let api = _shared else {
            fatalError("You must call `TjekEventsTracker.initialize` before you access `TjekEventsTracker.shared`.")
        }
        return api
    }
    
    // MARK: -
    
    public let config: Config
    
    /// The `Context` that will be attached to all future events (at the moment of tracking).
    /// Modifying the context will only change events that are tracked in the future
    public var context: Context = Context()
    
    internal var viewTokenizer: UniqueViewTokenizer
    fileprivate let saltStore: SaltStore
    fileprivate let pool: EventsPool
    
    public init(config: Config, saltStore: SaltStore) {
        self.config = config
        
        self.saltStore = saltStore
        self.viewTokenizer = UniqueViewTokenizer.load(from: saltStore)
        
        let eventsShipper = EventsShipper(baseURL: config.baseURL, dryRun: config.enabled == false, appContext: .init(id: config.appId))
        let eventsCache = EventsCache<ShippableEvent>(fileName: "com.shopgun.ios.sdk.events_pool.disk_cache.v2.plist")
        
        self.pool = EventsPool(dispatchInterval: config.dispatchInterval,
                               dispatchLimit: config.dispatchLimit,
                               shippingHandler: eventsShipper.ship,
                               cache: eventsCache)
        
        TjekEventsTracker.legacyPoolCleaner(baseURL: config.baseURL, enabled: config.enabled) { (cleanedEvents) in
#warning("Log cleaned events?: LH - 1 Nov 2021")
            //            Logger.log("LegacyEventsPool cleaned (\(cleanedEvents) events)", level: .debug, source: .EventsTracker)
        }
    }
    
    private init() { fatalError("You must provide config when creating a TjekEventsTracker") }
    
    /// This will generate a new tokenizer with a new salt. Calling this will mean that any ViewToken sent with future events will not be connected to any historically shipped events.
    public func resetViewTokenizerSalt() {
        self.viewTokenizer = UniqueViewTokenizer.reload(from: self.saltStore)
    }
}

// MARK: - Tracking methods

extension TjekEventsTracker {
    public func trackEvent(_ event: Event) {
        
        // TODO: Do on shared queue?
        
        // Mark the event with the tracker's context & appId
        let eventToTrack = event
            .addingAppIdentifier(self.config.appId)
            .addingContext(self.context)
        
        // push the event to the cached pool
        guard let shippableEvent = ShippableEvent(event: eventToTrack) else { return }
        
        self.pool.push(event: shippableEvent)
        
        let eventInfo = [TjekEventsTracker.trackedEventNotificationKey: eventToTrack]
        
#warning("Log event tracked: LH - 1 Nov 2021")
        //        Logger.log("📩 Event Tracked: \(shippableEvent)", level: .debug, source: .EventsTracker)
        
        // send a notification
        NotificationCenter.default.post(name: TjekEventsTracker.didTrackEventNotification,
                                        object: self,
                                        userInfo: eventInfo)
    }
}

// MARK: - Tracking Notifications

extension TjekEventsTracker {
    
    /// The NotificationName for notifications posted when events are tracked. The Notification's userInfo contains the event. See `extractTrackedEvent(from:)` for an easy way to get the event from the Notification.
    public static let didTrackEventNotification = Notification.Name(rawValue: "TjekSDK.EventsTracker.eventTracked")
    
    /// The key to access the event in the `didTrackEventNotification` notification's userInfo dictionary.
    fileprivate static let trackedEventNotificationKey = "trackedEvent"
    
    /**
     Given a Notification triggered by the `didTrackEventNotification` with the name, this will look in the userInfo and return the `Event` object, if it exists. The result will be `nil` if the Notification is not of the correct kind, or userInfo doesnt contain an event.
     - parameter notification: The Notification to extract the `Event` from.
     */
    public static func extractTrackedEvent(from notification: Notification) -> Event? {
        guard notification.name == TjekEventsTracker.didTrackEventNotification else {
            return nil
        }
        
        return notification.userInfo?[TjekEventsTracker.trackedEventNotificationKey] as? Event
    }
}

// MARK: - Config Loading

extension TjekEventsTracker.Config {
    /// Try to load from first the updated plist, and after that the legacy plist. If both fail, returns the error from the updated plist load.
    static func loadFromPlist(inBundle bundle: Bundle = .main) throws -> Self {
        do {
            let fileName = "TjekSDK-Config.plist"
            guard let filePath = bundle.url(forResource: fileName, withExtension: nil) else {
                struct FileNotFound: Error { var fileName: String }
                throw FileNotFound(fileName: fileName)
            }
            
            return try load(fromPlist: filePath)
        } catch {
            let legacyFileName = "ShopGunSDK-Config.plist"
            if let legacyFilePath = bundle.url(forResource: legacyFileName, withExtension: nil),
               let legacyConfig = try? load(fromPlist: legacyFilePath) {
                // legacy plist has same structure as updated plist
                return legacyConfig
            } else {
                throw error
            }
        }
    }
    
    static func load(fromPlist filePath: URL) throws -> Self {
        let data = try Data(contentsOf: filePath, options: [])
        
        struct ConfigContainer: Decodable {
            struct Values: Decodable {
                var appId: String
            }
            var EventsTracker: Values
        }
        
        let fileValues = (try PropertyListDecoder().decode(ConfigContainer.self, from: data)).EventsTracker
        
        return try Self(
            appId: AppIdentifier(rawValue: fileValues.appId)
        )
    }
}

extension KeychainDataStore.Config {
    
    static func loadFromPlist(inBundle bundle: Bundle = .main) throws -> Self {
        do {
            let fileName = "TjekSDK-Config.plist"
            guard let filePath = bundle.url(forResource: fileName, withExtension: nil) else {
                struct FileNotFound: Error { var fileName: String }
                throw FileNotFound(fileName: fileName)
            }
            
            return try load(fromPlist: filePath)
        } catch {
            let legacyFileName = "ShopGunSDK-Config.plist"
            if let legacyFilePath = bundle.url(forResource: legacyFileName, withExtension: nil),
               let legacyConfig = try? load(fromPlist: legacyFilePath) {
                // legacy plist has same structure as updated plist
                return legacyConfig
            } else {
                throw error
            }
        }
    }
    
    static func load(fromPlist filePath: URL) throws -> Self {
        let data = try Data(contentsOf: filePath, options: [])
        
        struct ConfigContainer: Decodable {
            var KeychainGroupId: String?
            var KeychainPrivateId: String?
        }
        
        let config = (try PropertyListDecoder().decode(ConfigContainer.self, from: data))

        if let keychainGroupId = config.KeychainGroupId {
            return .sharedKeychain(groupId: keychainGroupId)
        } else {
            let privateId = config.KeychainPrivateId
            return .privateKeychain(id: privateId)
        }
    }
}

extension SaltStore {
    public static func keychain(_ keychain: KeychainDataStore) -> SaltStore {
        // The key to access the salt from the dataStore. This is named as such for legacy reasons.
        let saltKey = "ShopGunSDK.EventsTracker.ClientId"
        return SaltStore(
            get: {
                keychain.get(for: saltKey)
            },
            set: {
                keychain.set(value: $0, for: saltKey)
            }
        )
    }
}
