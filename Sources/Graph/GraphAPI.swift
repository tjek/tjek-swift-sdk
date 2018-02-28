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

private typealias GraphAPI_Settings = GraphAPI
extension GraphAPI_Settings {
    
    public struct Settings {
        public var key: String
        public var baseURL: URL
        
        public init(key: String, baseURL: URL = URL(string: "https://graph.service.shopgun.com")!) {
            self.key = key
            self.baseURL = baseURL
        }
    }
}
