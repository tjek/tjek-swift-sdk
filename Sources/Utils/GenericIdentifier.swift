//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

/* GenericIdentifier is a phantom type, that uses the generic T for compile-time typesafety.
 *
 * struct Person: Codable {
 *  typealias Identifier = GenericIdentifier<Person>
 *  let id:Identifier
 * }
 *
 * So now you cannot accidently interchange one type of identifier for another,
 * even though internally (and when encoded) they are both just strings
 */
public struct GenericIdentifier<T>: RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init?(rawValue: String?) {
        guard let raw = rawValue else { return nil }
        self.init(rawValue: raw)
    }
    
    public static func generate(lowercased: Bool = false) -> GenericIdentifier<T> {
        var uuid = UUID().uuidString
        if lowercased {
            uuid = uuid.lowercased()
        }
        return .init(rawValue:uuid)
    }
}

/// Allow identifier to be Encoded & decoded using the rawValue
extension GenericIdentifier: Codable { }

/// Allow identifier to be used as a key
extension GenericIdentifier: Hashable {
    public var hashValue: Int { return rawValue.hashValue }
}

/// Allpw the Identifier to be init'd as a literal string `"abc"`
extension GenericIdentifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
}
