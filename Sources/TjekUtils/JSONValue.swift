///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

public enum JSONValue: Equatable {
    case string(String)
    case int(Int)
    case number(Float)
    case object([String: JSONValue])
    case array([JSONValue])
    case bool(Bool)
    case null
}

extension JSONValue {
    
    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }
    public var intValue: Int? {
        guard case .int(let value) = self else { return nil }
        return value
    }
    public var numberValue: Float? {
        guard case .number(let value) = self else { return nil }
        return value
    }
    public var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }
    public var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }
    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
    public var isNullValue: Bool {
        guard case .null = self else { return false }
        return true
    }
}

// MARK: -

extension JSONValue {
    
    public var nonNullValue: JSONValue? {
        return isNullValue ? nil : self
    }
    
    public func removingAllNullValues(recursively: Bool = true) -> JSONValue? {
        guard !isNullValue else {
            return nil
        }
        guard recursively else {
            return self
        }
        
        switch self {
        case .array(let array):
            return .array(array.removingAllNullValues(recursively: true))
        case .object(let dict):
            return .object(dict.removingAllNullValues(recursively: true))
        default:
            return self
        }
    }
}

extension Array where Element == JSONValue {
    public func removingAllNullValues(recursively: Bool = true) -> Array {
        self.compactMap({ $0.removingAllNullValues(recursively: recursively) })
    }
}

extension Dictionary where Value == JSONValue {
    public func removingAllNullValues(recursively: Bool = true) -> Dictionary {
        self.compactMapValues({ $0.removingAllNullValues(recursively: recursively) })
    }
}

// MARK: -

extension JSONValue: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case let .array(array):
            try container.encode(array)
        case let .object(object):
            try container.encode(object)
        case let .string(string):
            try container.encode(string)
        case let .int(int):
            try container.encode(int)
        case let .number(number):
            try container.encode(number)
        case let .bool(bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let number = try? container.decode(Float.self) {
            self = .number(number)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value.")
            )
        }
    }
}

// MARK: -

extension JSONValue: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
        case .string(let str):
            return str.debugDescription
        case .number(let num):
            return num.debugDescription
        case .int(let int):
            return int.description
        case .bool(let bool):
            return bool.description
        case .null:
            return "null"
        default:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            return (try? String(data: encoder.encode(self), encoding: .utf8)!) ?? "<Invalid JSON>"
        }
    }
}

// MARK: -

public protocol JSONValueRepresentable {
    var jsonValue: JSONValue { get }
}

extension JSONValue: JSONValueRepresentable {
    @inlinable
    public var jsonValue: JSONValue { self }
}

extension Int: JSONValueRepresentable {
    public var jsonValue: JSONValue { .int(self) }
}

extension Float: JSONValueRepresentable {
    public var jsonValue: JSONValue { .number(self) }
}
extension Double: JSONValueRepresentable {
    public var jsonValue: JSONValue { .number(Float(self)) }
}

#if canImport(CoreGraphics)
import CoreGraphics
extension CGFloat: JSONValueRepresentable {
    public var jsonValue: JSONValue { .number(Float(self)) }
}
#endif

extension String: JSONValueRepresentable {
    public var jsonValue: JSONValue { .string(self) }
}

extension Dictionary: JSONValueRepresentable where Key == String, Value: JSONValueRepresentable {
    public var jsonValue: JSONValue { .object(self.mapValues(\.jsonValue)) }
}

extension Array: JSONValueRepresentable where Element: JSONValueRepresentable {
    public var jsonValue: JSONValue { .array(self.map(\.jsonValue)) }
}

extension Set: JSONValueRepresentable where Element: JSONValueRepresentable {
    public var jsonValue: JSONValue { .array(self.map(\.jsonValue)) }
}

extension Bool: JSONValueRepresentable {
    public var jsonValue: JSONValue { .bool(self) }
}

extension Optional: JSONValueRepresentable where Wrapped: JSONValueRepresentable {
    public var jsonValue: JSONValue { self.map(\.jsonValue) ?? .null }
}

extension GenericIdentifier: JSONValueRepresentable {
    public var jsonValue: JSONValue { self.rawValue.jsonValue }
}
