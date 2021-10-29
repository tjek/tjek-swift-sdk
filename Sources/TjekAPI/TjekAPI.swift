///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

public class TjekAPI {
    
    public struct Config: Decodable {
        public var apiKey: String
        public var apiSecret: String
        public var clientVersion: String
        public var baseURL: URL = URL(string: "https://squid-api.tjek.com")!
        
        static func load(fromPlist fileName: String, clientVersion: String) throws -> Config {
            #warning("throw an error here: LH - 29 Oct 2021")
            guard let filePath = Bundle.main.url(forResource: fileName, withExtension: nil) else {
                fatalError("Unable to find config file '\(fileName)'")
            }
            
            let data = try Data(contentsOf: filePath, options: [])
            
            #warning("Also handle legacy files: LH - 29 Oct 2021")
            struct ConfigContainer: Decodable {
                struct Values: Decodable {
                    var key: String
                    var secret: String
                }
                var api: Values
            }
            
            let fileValues = (try PropertyListDecoder().decode(ConfigContainer.self, from: data)).api
            
            return Config(
                apiKey: fileValues.key,
                apiSecret: fileValues.secret,
                clientVersion: clientVersion
            )
        }
        
    }
    
    /// Initialize the `shared` TjekAPI
    public static func initialize(config: Config) {
        _shared = TjekAPI(config: config)
    }
    
    /// Initialize the `shared` TjekAPI using the config file
    public static func initialize(clientVersion: String) {
        initialize(config: try! .load(fromPlist: "ShopGunSDK-Config.plist", clientVersion: clientVersion))
    }
    
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
    }
    
    public let v2: APIClient
    
}

public struct LocationQuery {
    public var coordinate: (lat: Double, lng: Double)
    /// In Meters
    public var maxRadius: Int? = nil
    
    public init(coordinate: (lat: Double, lng: Double), maxRadius: Int? = nil) {
        self.coordinate = coordinate
        self.maxRadius = maxRadius
    }
}

extension APIRequest {
    func paginatedResponse<ResponseElement>(paginatedRequest: PaginatedRequest<Int>) -> APIRequest<PaginatedResponse<ResponseElement, Int>> where ResponseType == [ResponseElement] {
        self.map({
            PaginatedResponse(
                results: $0,
                expectedCount: paginatedRequest.itemCount,
                startingAtOffset: paginatedRequest.startCursor
            )
        })
    }
}
