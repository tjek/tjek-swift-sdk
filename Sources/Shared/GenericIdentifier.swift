//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

/**
 GenericIdentifier is a phantom type, that uses the generic T for compile-time typesafety.
 
 ```swift
 struct Person: Codable {
    typealias Identifier = GenericIdentifier<Person>
    let id: Identifier
 }
 ```
 
 So now you cannot accidently interchange one type of identifier for another, even though internally (and when encoded) they are both just strings.
 
 If you need create a T just for defining a secondary Identifier within a type, one way is to use an empty enum. eg:
 
 ```swift
 struct AuthVault {
    enum SessionType {}
    typealias SessionIdentifier = GenericIdentifier<SessionType>
    let sessionId: SessionIdentifier
 }
 ```
 */
public struct GenericIdentifier<T>: RawRepresentable, Hashable {
    
    /// The internal string value of the GenericIdentifier.
    public let rawValue: String
    
    /**
     Creates a new GenericIdentifier with the specified `rawValue` string
     - parameter rawValue: The string value to use for this identifier.
     */
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    /**
     Creates a new GenericIdentifier with the specified optional `rawValue` string, or fails if `rawValue` is nil.
     - parameter rawValue: The optional string value to use for this identifier.
     */
    public init?(rawValue: String?) {
        guard let raw = rawValue else {
            return nil
        }
        self.init(rawValue: raw)
    }
    
    /**
     Create a new `GenericIdentifier` with an `id` set to a new uuidString.
     - parameter lowercased: Should the uuid string be made lowercase.
     */
    public static func generate(lowercased: Bool = false) -> GenericIdentifier<T> {
        var uuid = UUID().uuidString
        if lowercased {
            uuid = uuid.lowercased()
        }
        return .init(rawValue:uuid)
    }
}

/// Allow identifier to be Encoded & decoded using the rawValue
extension GenericIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension GenericIdentifier: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}

extension GenericIdentifier: ExpressibleByStringLiteral {
    /// Allow the Identifier to be init'd as a literal string `"abc"`
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
    /// Allow the Identifier to be init'd as a literal string `"abc"`
    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }
    /// Allow the Identifier to be init'd as a literal string `"abc"`
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
}
