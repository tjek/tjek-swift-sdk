//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension EventsTracker {
    /// A container for representing an id in an event's properties
    public class IdField: NSObject {
        public let id: String
        public let source: String
        
        public init(_ id: String, source: String) {
            self.id = id
            self.source = source
        }
        
        public func jsonArray() -> [String] {
            return [source, id]
        }
        
        public static func legacy(_ id: String) -> IdField {
            return IdField(id, source: "legacy")
        }
        public static func legacy(_ id: String?) -> IdField? {
            guard let id = id else { return nil }
            return legacy(id)
        }
        public static func graph(_ id: String) -> IdField {
            return IdField(id, source: "graph")
        }
        public static func graph(_ id: String?) -> IdField? {
            guard let id = id else { return nil }
            return graph(id)
        }
    }
}
