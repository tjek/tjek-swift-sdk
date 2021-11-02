///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

public class TjekAPI {
    
    public struct Config: Equatable {
        public var apiKey: String
        public var apiSecret: String
        public var clientVersion: String
        public var baseURL: URL
        
        public init(apiKey: String, apiSecret: String, clientVersion: String = shortBundleVersion(.main), baseURL: URL = URL(string: "https://squid-api.tjek.com")!) throws {
            
            guard !apiKey.isEmpty else {
                struct APIKeyEmpty: Error { }
                throw APIKeyEmpty()
            }
            guard !apiSecret.isEmpty else {
                struct APISecretEmpty: Error { }
                throw APISecretEmpty()
            }
            
            self.apiKey = apiKey
            self.apiSecret = apiSecret
            self.clientVersion = clientVersion
            self.baseURL = baseURL
        }
    }
    
    /// Initialize the `shared` TjekAPI using the specified `Config`.
    public static func initialize(config: Config) {
        _shared = TjekAPI(config: config)
    }
    
    /**
     Initialize the `shared` TjekAPI using the config plist file.
     Config file should be placed in your main bundle, with the name `TjekSDK-Config.plist`.
     
     It must contain the following key/values:
     - `apiKey: "<your api key>"`
     - `apiSecret: "<your api secret>"`
     
     By default, `clientVersion` is the `CFBundleShortVersionString` of your `Bundle.main`.
     
     - Note: Throws if the config file is missing or malformed.
     */
    public static func initialize(clientVersion: String = shortBundleVersion(.main)) throws {
        let config = try Config.loadFromPlist(clientVersion: clientVersion)
        
        initialize(config: config)
    }
    
    public static var isInitialized: Bool { _shared != nil }
    
    private static var _shared: TjekAPI!
    
    /// Do not reference this instance of the TjekAPI until you have called one of the static `initialize` functions.
    public static var shared: TjekAPI {
        guard let api = _shared else {
            fatalError("You must call `TjekAPI.initialize` before you access `TjekAPI.shared`.")
        }
        return api
    }
    
    // MARK: -
    
    public let config: Config
    public let v2: APIClient
    public let v4: APIClient
    
    public init(config: Config) {
        self.config = config
        let urlSession = URLSession.shared
        let preferredLanguages = Locale.preferredLanguages.joined(separator: ",")
        
        // Initialize v2 API
        
        let v2df = DateFormatter()
        v2df.locale = Locale(identifier: "en_US_POSIX")
        v2df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        self.v2 = APIClient(
            baseURL: config.baseURL.appendingPathComponent("v2"),
            urlSession: urlSession,
            headers: ["content-type": "application/json; charset=utf-8",
                      "accept-encoding": "gzip",
                      "accept-language": preferredLanguages.isEmpty ? nil : preferredLanguages
                     ].compactMapValues({ $0 }),
            defaultEncoder: {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(v2df)
                return encoder
            }(),
            defaultDecoder: {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(v2df)
                return decoder
            }()
        )
        
        v2.setAPIKey(config.apiKey, apiSecret: config.apiSecret)
        v2.setClientVersion(config.clientVersion)
        
        // Initialize v4 API
        
        let v4df = ISO8601DateFormatter()
        v4df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        self.v4 = APIClient(
            baseURL: config.baseURL.appendingPathComponent("v4/rpc"),
            headers: ["content-type": "application/json; charset=utf-8",
                      "accept-encoding": "gzip",
                      "accept-language": preferredLanguages.isEmpty ? nil : preferredLanguages
                     ].compactMapValues({ $0 }),
            defaultEncoder: {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .customISO8601(v4df)
                return encoder
            }(),
            defaultDecoder: {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .customISO8601(v4df)
                return decoder
            }()
        )
        v4.setAPIKey(config.apiKey, apiSecret: config.apiSecret)
        v4.setClientVersion(config.clientVersion)
    }
}

// MARK: -

extension TjekAPI.Config {
    /// Try to load from first the updated plist, and after that the legacy plist. If both fail, returns the error from the updated plist load.
    static func loadFromPlist(inBundle bundle: Bundle = .main, clientVersion: String) throws -> Self {
        do {
            let fileName = "TjekSDK-Config.plist"
            guard let filePath = bundle.url(forResource: fileName, withExtension: nil) else {
                struct FileNotFound: Error { var fileName: String }
                throw FileNotFound(fileName: fileName)
            }
            
            return try load(fromPlist: filePath, clientVersion: clientVersion)
        } catch {
            let legacyFileName = "ShopGunSDK-Config.plist"
            if let legacyFilePath = bundle.url(forResource: legacyFileName, withExtension: nil),
                let legacyConfig = try? load(fromLegacyPlist: legacyFilePath, clientVersion: clientVersion) {
                return legacyConfig
            } else {
                throw error
            }
        }
    }
    
    static func load(fromPlist filePath: URL, clientVersion: String) throws -> Self {
        let data = try Data(contentsOf: filePath, options: [])
        
        struct Config: Decodable {
            var apiKey: String
            var apiSecret: String
        }
        
        let configFile = (try PropertyListDecoder().decode(Config.self, from: data))
        
        return try Self(
            apiKey: configFile.apiKey,
            apiSecret: configFile.apiSecret,
            clientVersion: clientVersion
        )
    }
    
    static func load(fromLegacyPlist filePath: URL, clientVersion: String) throws -> Self {
        let data = try Data(contentsOf: filePath, options: [])
        
        struct ConfigContainer: Decodable {
            struct Values: Decodable {
                var key: String
                var secret: String
            }
            var CoreAPI: Values
        }
        
        let fileValues = (try PropertyListDecoder().decode(ConfigContainer.self, from: data)).CoreAPI
        
        return try Self(
            apiKey: fileValues.key,
            apiSecret: fileValues.secret,
            clientVersion: clientVersion
        )
    }
}

// MARK: -

extension JSONEncoder.DateEncodingStrategy {
    fileprivate static func customISO8601(_ iso8601: ISO8601DateFormatter) -> Self {
        .custom({ date, encoder in
            var c = encoder.singleValueContainer()
            let dateStr = iso8601.string(from: date)
            try c.encode(dateStr)
        })
    }
}

extension JSONDecoder.DateDecodingStrategy {
    fileprivate static func customISO8601(_ iso8601: ISO8601DateFormatter) -> Self {
        .custom({ decoder in
            let c = try decoder.singleValueContainer()
            let dateStr = try c.decode(String.self)
            if let date = iso8601.date(from: dateStr) {
                return date
            } else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unable to decode date-string '\(dateStr)'")
            }
        })
    }
}

public func shortBundleVersion(_ bundle: Bundle) -> String {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
}
