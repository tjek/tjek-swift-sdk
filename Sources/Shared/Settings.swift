//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public class Settings: Decodable {
    public var keychainDataStore: Settings.KeychainDataStore
    public var coreAPI: Settings.CoreAPI? = nil
    public var graphAPI: Settings.GraphAPI? = nil
    public var eventsTracker: Settings.EventsTracker? = nil
    
    public static var defaultSettingsFileName = "ShopGunSDK-Config.plist"
    
    public static func loadShared() throws -> Settings {
        if let shared = _shared {
            return shared
        }
        
        // try to load. may throw.
        let fileName = Settings.defaultSettingsFileName
        guard let filePath = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            throw SettingsLoadError.fileNotFound(fileName: fileName)
        }
        
        guard let data = try? Data(contentsOf: filePath, options: []) else {
            throw SettingsLoadError.fileEmpty(filePath: filePath)
        }
        
        let loadedShared = try PropertyListDecoder().decode(Settings.self, from: data)
        
        _shared = loadedShared
        return loadedShared
    }
    
    private enum SettingsLoadError: Error {
        case fileNotFound(fileName: String)
        case fileEmpty(filePath: URL)
    }
    private static var _shared: Settings?
    
    // MARK: Decodable
    
    enum CodingKeys: String, CodingKey {
        case keychainGroupId = "KeychainGroupId"
        case coreAPI         = "CoreAPI"
        case graphAPI        = "GraphAPI"
        case eventsTracker   = "EventsTracker"
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let keychainGroupId = try? container.decode(String.self, forKey: .keychainGroupId) {
            self.keychainDataStore = .sharedKeychain(groupId: keychainGroupId)
        } else {
            self.keychainDataStore = .privateKeychain
        }
        
        self.coreAPI = try? container.decode(Settings.CoreAPI.self, forKey: .coreAPI)
        
        self.graphAPI = try? container.decode(Settings.GraphAPI.self, forKey: .graphAPI)
        
        self.eventsTracker = try? container.decode(Settings.EventsTracker.self, forKey: .eventsTracker)
    }
    
}

// MARK: - Component Settings

extension Settings {
    /**
     The settings for the KeychainDataStore.
     */
    public enum KeychainDataStore {
        case privateKeychain
        case sharedKeychain(groupId: String)
    }
}
extension Settings {
    /**
     The settings for the CoreAPI component.
     */
    public struct CoreAPI: Decodable {
        public var key: String
        public var secret: String
        public var baseURL: URL
        
        public init(key: String, secret: String, baseURL: URL = URL(string: "https://api.etilbudsavis.dk")!) {
            self.key = key
            self.secret = secret
            self.baseURL = baseURL
        }
        
        // MARK: Decodable
        
        enum CodingKeys: String, CodingKey {
            case key
            case secret
            case baseURL
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let key = try container.decode(String.self, forKey: .key)
            let secret = try container.decode(String.self, forKey: .secret)
            
            self.init(key: key, secret: secret)
            
            if let baseURLStr = try? container.decode(String.self, forKey: .baseURL), let baseURL = URL(string: baseURLStr) {
                self.baseURL = baseURL
            }
        }
    }
}

extension Settings {
    /**
     Settings for the GraphAPI component.
     */
    public struct GraphAPI: Decodable {
        public var key: String
        public var baseURL: URL
        
        public init(key: String, baseURL: URL = URL(string: "https://graph.service.shopgun.com")!) {
            self.key = key
            self.baseURL = baseURL
        }
        
        // MARK: Decodable
        
        enum CodingKeys: String, CodingKey {
            case key
            case baseURL
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let key = try container.decode(String.self, forKey: .key)
            self.init(key: key)
            
            if let baseURLStr = try? container.decode(String.self, forKey: .baseURL), let baseURL = URL(string: baseURLStr) {
                self.baseURL = baseURL
            }
        }
    }
}

extension Settings {
    /**
     The settings for the EventsTracker component.
     */
    public struct EventsTracker: Decodable {
        public var trackId: String
        public var baseURL: URL
        public var dispatchInterval: TimeInterval
        public var dispatchLimit: Int
        public var enabled: Bool
        public var includeLocation: Bool
        
        public init(trackId: String, baseURL: URL = URL(string: "https://events.service.shopgun.com")!, dispatchInterval: TimeInterval = 120.0, dispatchLimit: Int = 100, enabled: Bool = true, includeLocation: Bool = false) {
            self.trackId = trackId
            self.baseURL = baseURL
            self.dispatchInterval = dispatchInterval
            self.dispatchLimit = dispatchLimit
            self.enabled = enabled
            self.includeLocation = includeLocation
        }
        
        // MARK: Decodable
        
        enum CodingKeys: String, CodingKey {
            case trackId
            case baseURL
            case dispatchInterval
            case dispatchLimit
            case enabled
            case includeLocation
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let trackId = try container.decode(String.self, forKey: .trackId)
            
            self.init(trackId: trackId)
            
            if let baseURLStr = try? container.decode(String.self, forKey: .baseURL), let baseURL = URL(string: baseURLStr) {
                
                self.baseURL = baseURL
            }
            
            if let dispatchInterval = try? container.decode(TimeInterval.self, forKey: .dispatchInterval) {
                self.dispatchInterval = dispatchInterval
            }
            
            if let dispatchLimit = try? container.decode(Int.self, forKey: .dispatchLimit) {
                self.dispatchLimit = dispatchLimit
            }
            
            if let enabled = try? container.decode(Bool.self, forKey: .enabled) {
                self.enabled = enabled
            }
            
            if let includeLocation = try? container.decode(Bool.self, forKey: .includeLocation) {
                self.includeLocation = includeLocation
            }
        }
    }
}
