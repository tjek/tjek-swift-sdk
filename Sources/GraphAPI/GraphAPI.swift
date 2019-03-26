//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

final public class GraphAPI {
    public let settings: Settings.GraphAPI
    
    internal init(settings: Settings.GraphAPI) {
        self.settings = settings
    }
    
    private init() { fatalError("You must provide settings when creating the GraphAPI") }
    
    public lazy var client: NetworkGraphClient = {
        return NetworkGraphClient(graphAPI: self)
    }()
}

// MARK: -

extension GraphAPI {
    fileprivate static var _shared: GraphAPI?
    
    public static var shared: GraphAPI {
        guard let graphAPI = _shared else {
            fatalError("Must call `GraphAPI.configure(…)` before accessing `shared`")
        }
        return graphAPI
    }
    
    public static var isConfigured: Bool {
        return _shared != nil
    }
    
    public static func configure() {
        do {
            guard let settings = try Settings.loadShared().graphAPI else {
                fatalError("Required GraphAPI settings missing from '\(Settings.defaultSettingsFileName)'")
            }
            
            configure(settings)
        } catch let error {
            fatalError(String(describing: error))
        }
    }
    
    public static func configure(_ settings: Settings.GraphAPI) {
        
        if isConfigured {
            Logger.log("Re-configuring GraphAPI", level: .verbose, source: .GraphAPI)
        } else {
            Logger.log("Configuring GraphAPI", level: .verbose, source: .GraphAPI)
        }
        
        _shared = GraphAPI(settings: settings)
    }
}



// An GraphClient for connecting to the ShopGun Graph service. It handles auth with AppKeys.
extension NetworkGraphClient {
    convenience init(url: URL, appKey: String? = nil) {
        var additionalHeaders: [String: String]? = nil
        
        if let realAppKey = appKey, let authData = "app-key:\(realAppKey)".data(using: .utf8) {
            
            let base64EncodedCredential = authData.base64EncodedString()
            let authString = "Basic \(base64EncodedCredential)"
            
            additionalHeaders = ["Authorization": authString]
        }
        
        let connection = HTTPGraphNetworkTransport(url: url, additionalHeaders: additionalHeaders, configuration: URLSessionConfiguration.default)
        
        self.init(connection: connection)
    }
    
    convenience init(graphAPI: GraphAPI) {
        self.init(
            url: graphAPI.settings.baseURL,
            appKey: graphAPI.settings.key
        )
    }
}
