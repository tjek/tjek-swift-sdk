///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

#if !COCOAPODS // Cocoapods merges these modules
@_exported import TjekAPI
@_exported import TjekEventsTracker
@_exported import TjekUtils
#if os(iOS)
@_exported import TjekPublicationViewer
#endif
#endif

public struct TjekSDK {
    
    public struct Config {
        public var api: TjekAPI.Config
        public var eventsTracker: TjekEventsTracker.Config
        
        public init(api: TjekAPI.Config, eventsTracker: TjekEventsTracker.Config) {
            self.api = api
            self.eventsTracker = eventsTracker
        }
        
        public init(apiKey: String, apiSecret: String, trackId: TjekEventsTracker.Config.TrackId, clientVersion: String = shortBundleVersion(.main)) throws {
            self.api = try .init(apiKey: apiKey, apiSecret: apiSecret, clientVersion: clientVersion)
            self.eventsTracker = try .init(trackId: trackId)
        }
    }
    
    public static var api: TjekAPI { TjekAPI.shared }
    public static var eventsTracker: TjekEventsTracker { TjekEventsTracker.shared }
    public static var logger: TjekLogger { TjekLogger.shared }
    
    public static func initialize(clientVersion: String = shortBundleVersion(.main)) throws {
        try TjekAPI.initialize(clientVersion: clientVersion)
        try TjekEventsTracker.initialize()
    }
    
    public static func initialize(config: Config) {
        TjekAPI.initialize(config: config.api)
        TjekEventsTracker.initialize(config: config.eventsTracker)
    }
}
