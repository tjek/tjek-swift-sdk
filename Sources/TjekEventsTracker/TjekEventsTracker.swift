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
    
    /// Initialize the `shared` TjekEventsTracker using the specified `Config`.
    public static func initialize(config: Config) {
        _shared = TjekEventsTracker(config: config)
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

        initialize(config: config)
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
    
    public init(config: Config) {
        self.config = config
    }
}

// MARK: -

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
