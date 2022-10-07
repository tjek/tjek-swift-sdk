///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation
#if !COCOAPODS // Cocoapods merges these modules
import TjekUtils
#endif

public actor TjekAPI {
    
    public struct Config: Equatable {
        public var apiKey: String
        public var clientVersion: String
        public var baseURL: URL
        
        public init(apiKey: String, clientVersion: String = shortBundleVersion(.main), baseURL: URL = URL(string: "https://squid-api.tjek.com")!) throws {
            guard !apiKey.isEmpty else {
                struct APIKeyEmpty: Error { }
                throw APIKeyEmpty()
            }
            
            self.apiKey = apiKey
            self.clientVersion = clientVersion
            self.baseURL = baseURL
        }
        
        @available(*, deprecated, message: "apiSecret is no longer needed")
        public init(apiKey: String, apiSecret: String, clientVersion: String = shortBundleVersion(.main), baseURL: URL = URL(string: "https://squid-api.tjek.com")!) throws {
            try self.init(apiKey: apiKey, clientVersion: clientVersion, baseURL: baseURL)
        }
    }
    
    /**
     Initialize the `shared` TjekAPI using the specified `Config`.
     Will fatalError if you call after the API has already been initialized.
     If you wish to re-initialize the shared api, use `await TjekAPI.shared.update(config:)`
     */
    public static func initialize(config: Config) {
        if _shared != nil {
            fatalError("TjekAPI is already initialized. Use `await TjekAPI.shared.update(config:)` to re-initialize.")
        } else {
            _shared = TjekAPI(config: config)
        }
    }
    
    /**
     Initialize the `shared` TjekAPI using the config plist file.
     Config file should be placed in your main bundle, with the name `TjekSDK-Config.plist`.
     
     It must contain the following key/value:
     - `apiKey: "<your api key>"`
     
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
        guard let shared = _shared else {
            fatalError("You must call `TjekAPI.initialize` before you access `TjekAPI.shared`.")
        }
        return shared
    }
    
    // MARK: -
    
    public init(
        config: Config,
        willSendRequest: @escaping URLRequestBuilder = { _ in },
        didReceiveResponse: @escaping APIResponseListener = { _, _ in }
    ) {
        self.config = config
        self.willSendRequest = willSendRequest
        self.didReceiveResponse = didReceiveResponse
    }
    
    fileprivate var willSendRequest: URLRequestBuilder
    fileprivate var didReceiveResponse: APIResponseListener
    
    /// The `URLRequestBuilder` callback you add here will be called after previously added builders have been called.
    /// It will give you the opportunity to modify the URLRequest before it is sent.
    /// Note, this callback is `async`, meaning that any work you do in here will block the sending of any future requests until finished.
    public func addWillSendRequestBuilder(_ builder: @escaping URLRequestBuilder) {
        let prevReqBuilder = self.willSendRequest
        self.willSendRequest = { urlReq in
            try await prevReqBuilder(&urlReq)
            try await builder(&urlReq)
        }
    }
    /// The `APIResponseListener` callback is called after previously added listeners have been called.
    /// It will give you an opportunity to react to the response from the request.
    /// Note, this callback is `async`, meaning that any work you do in here will delay the original send request from completing.
    public func addDidReceiveResponseListener(_ listener: @escaping APIResponseListener) {
        let prevResponseListener = self.didReceiveResponse
        self.didReceiveResponse = { urlReq, result in
            await prevResponseListener(urlReq, result)
            await listener(urlReq, result)
        }
    }
    
    public var config: Config
    public func update(config: Config) {
        let oldConfig = self.config
        self.config = config
        
        if oldConfig != config {
            // setting to nil causes getClient() to rebuild a new client
            self._client = nil
        }
    }
    
    fileprivate var _client: APIClient?
    
    public func getClient() -> APIClient {
        if let client = self._client {
            return client
        } else {
            
            TjekLogger.info("[TjekSDK] Initializing TjekAPI Client")
            
            let client = APIClient(
                baseURL: self.config.baseURL,
                willSendRequest: { [weak self] urlReq in
                    if urlReq.apiKey == nil, let apiKey = await self?.config.apiKey {
                        urlReq.apiKey = apiKey
                    }
                    
                    urlReq.addValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
                    urlReq.addValue("gzip", forHTTPHeaderField: "accept-encoding")
                    urlReq.addValue(generateUserAgent(), forHTTPHeaderField: "user-agent")
                    let preferredLanguages = Locale.preferredLanguages.joined(separator: ",")
                    if !preferredLanguages.isEmpty {
                        urlReq.addValue(preferredLanguages, forHTTPHeaderField: "accept-language")
                    }
                    
                    try await self?.willSendRequest(&urlReq)
                },
                didReceiveResponse: { [weak self] urlReq, responseResult in
                    switch responseResult {
                    case .success(let httpResponse):
                        // Log any deprecation warnings
                        let deprecationReason = httpResponse.value(forHTTPHeaderField: "X-Api-Deprecation-Info")
                        let deprecationDate = httpResponse.value(forHTTPHeaderField: "X-Api-Deprecation-Date")
                        if deprecationReason != nil || deprecationDate != nil {
                            let deprecationInfo = [deprecationReason, deprecationDate.map({ "(\($0))" })].compactMap({ $0 }).joined(separator: " ")
                            TjekLogger.warning("🏚 DEPRECATED ENDPOINT '\(urlReq)': \(deprecationInfo)")
                        }
                        
                    case .failure(let error):
                        // Log any failed requests
                        TjekLogger.error("Request '\(urlReq)' failed: \(error.localizedDescription)")
                    }
                    
                    await self?.didReceiveResponse(urlReq, responseResult)
                }
            )
            
            self._client = client
            return client
        }
    }
}

extension TjekAPI: APIRequestSender {
    public func send<ResponseType>(_ request: APIRequest<ResponseType>) async -> Result<ResponseType, APIError> {
        await self.getClient().send(request)
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
        }
        
        let configFile = (try PropertyListDecoder().decode(Config.self, from: data))
        
        return try Self(
            apiKey: configFile.apiKey,
            clientVersion: clientVersion
        )
    }
    
    static func load(fromLegacyPlist filePath: URL, clientVersion: String) throws -> Self {
        let data = try Data(contentsOf: filePath, options: [])
        
        struct ConfigContainer: Decodable {
            struct Values: Decodable {
                var key: String
            }
            var CoreAPI: Values
        }
        
        let fileValues = (try PropertyListDecoder().decode(ConfigContainer.self, from: data)).CoreAPI
        
        return try Self(
            apiKey: fileValues.key,
            clientVersion: clientVersion
        )
    }
}

// MARK: -

public func shortBundleVersion(_ bundle: Bundle) -> String {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
}
