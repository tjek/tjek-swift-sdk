//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

/// An error that can be emitted by the graph
public struct GraphError: Error {
    public let message: String
    public let path: [String]
    
    public init(message: String, path: [String]) {
        self.message = message
        self.path = path
    }
}

/// Pretty-printing error descriptions
extension GraphError: CustomStringConvertible {
    public var description: String {
        return "'\(message)' path:\(path)"
    }
}
extension GraphError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}

/// JSON constructor for GraphError
extension GraphError {
    public init?(json: [String: Any]) {
        
        var message: String? = nil
        
        if let messageStr = json["message"] as? String {
            message = messageStr
        } else if let reasonStr = json["reason"] as? String {
            message = reasonStr
        } else if let reasonDict = json["reason"] as? [String: Any],
            let reasonMessage = reasonDict["message"] as? String {
            
            message = reasonMessage
        }
        
        guard message != nil, let path = json["path"] as? [String] else {
            return nil
        }
        
        self.init(message: message!, path: path)
    }
}
