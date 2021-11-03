///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

@_exported import TjekAPI
@_exported import TjekEventsTracker
#if canImport(TjekCatalogViewer)
@_exported import TjekCatalogViewer
#endif

public struct TjekSDK {
    
    public struct Config {
        public var api: TjekAPI.Config
        public var eventsTracker: TjekEventsTracker.Config
    }
    
    public static var api: TjekAPI { TjekAPI.shared }
    public static var eventsTracker: TjekEventsTracker { TjekEventsTracker.shared }
    
    public static func initialize(clientVersion: String = shortBundleVersion(.main)) throws {
        try TjekAPI.initialize()
        try TjekEventsTracker.initialize()
    }
    
    public static func initialize(config: Config) {
        TjekAPI.initialize(config: config.api)
        TjekEventsTracker.initialize(config: config.eventsTracker)
    }
}
