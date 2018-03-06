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
    public let settings: Settings
    
    internal init(settings: Settings) {
        self.settings = settings
    }
    
    private init() { fatalError("You must provide settings when creating the GraphAPI") }
}

// MARK: -

extension GraphAPI {
    
    public struct Settings {
        public var key: String
        public var baseURL: URL
        
        public init(key: String, baseURL: URL = URL(string: "https://graph.service.shopgun.com")!) {
            self.key = key
            self.baseURL = baseURL
        }
    }
    
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
    
    // This will cause a fatalError if KeychainDataStore hasnt been configured
    public static func configure(_ settings: GraphAPI.Settings) {
        
        if isConfigured {
            Logger.log("Re-configuring GraphAPI", level: .verbose, source: .GraphAPI)
        } else {
            Logger.log("Configuring GraphAPI", level: .verbose, source: .GraphAPI)
        }
        
        _shared = GraphAPI(settings: settings)
    }
}
