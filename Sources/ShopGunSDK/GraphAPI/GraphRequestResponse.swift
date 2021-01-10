//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

public struct GraphResponse {
    public var data: GraphDict?
    public var errors: [GraphError]?
}

// MARK: - Request

public protocol GraphRequestProtocol {
    var query: GraphQuery { get }
    var timeoutInterval: TimeInterval { get }
    var additionalHeaders: [String: String]? { get }
}

/// Generic, concrete request
public struct GraphRequest: GraphRequestProtocol {
    public let query: GraphQuery
    public let timeoutInterval: TimeInterval
    public let additionalHeaders: [String: String]?
    
    public init(query: GraphQuery, timeoutInterval: TimeInterval = 30, additionalHeaders: [String: String]? = nil) {
        self.query = query
        self.timeoutInterval = timeoutInterval
        self.additionalHeaders = additionalHeaders
    }
}
