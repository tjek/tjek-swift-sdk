//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public enum AppIdentiferType { }
public typealias AppIdentifier = GenericIdentifier<AppIdentiferType> // TODO

public struct Event {
    public typealias Identifier = GenericIdentifier<Event>
    public typealias PayloadType = [String: JSONValue]
    
    public let id: Identifier
    public let version: Int
    public let timestamp: Date
    public let type: Int
    
    public private(set) var payload: PayloadType
    
    public init(id: Identifier = Identifier.generate(), version: Int, timestamp: Date = Date(), type: Int, payload: PayloadType = [:]) {
        self.id = id
        self.version = version
        self.timestamp = timestamp
        self.type = type
        self.payload = payload
    }
    
    /// Will merge the newPayload into the old one. New values for existing keys will be used (so be careful!)
    mutating func mergePayload(_ newPayload: PayloadType) {
        self.payload.merge(newPayload) { (_, new) in new }
    }
}

// MARK: - Codable

extension Date {
    var eventTimestamp: Int {
        return Int(timeIntervalSince1970)
    }
    
    init(eventTimestamp: Int) {
        self = .init(timeIntervalSince1970: TimeInterval(eventTimestamp))
    }
}

extension Event: Codable {
    
    enum CodingKeys: CodingKey {
        case id
        case version
        case type
        case timestamp
        case payload(key: String)
        
        var stringValue: String {
            switch self {
            case .id:        return "_i"
            case .version:   return "_v"
            case .type:      return "_e"
            case .timestamp: return "_t"
            case .payload(let key): return key
            }
        }
        init?(stringValue: String) {
            if let key = CodingKeys.requiredKeys.first(where: { stringValue == $0.stringValue }) {
                self = key
            } else {
                self = .payload(key: stringValue)
            }
        }
        
        static let requiredKeys: [CodingKeys] = [.id, .version, .type, .timestamp]
        
        var intValue: Int? { return Int(stringValue) }
        init?(intValue: Int) { self.init(stringValue: "\(intValue)") }
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let eventId = try container.decode(Event.Identifier.self, forKey: .id)
        let version = try container.decode(Int.self, forKey: .version)
        let type = try container.decode(Int.self, forKey: .type)
        let timestamp = try container.decode(Int.self, forKey: .timestamp)
        
        let payload: [String: JSONValue] = container.allKeys.reduce(into: [:], { (result, key) in
            // only decode non-known payload keys
            guard case .payload = key else { return }
            
            // decode the key as a JSONValue. Skip if nil.
            guard let value = try? container.decode(JSONValue.self, forKey: key) else { return }
            
            result[key.stringValue] = value
        })

        self.init(id: eventId, version: version, timestamp: Date(eventTimestamp: timestamp), type: type, payload: payload)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.id, forKey: .id)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.timestamp.eventTimestamp, forKey: .timestamp)
        
        try self.payload.forEach { key, value in
            try container.encode(value, forKey: .payload(key: key))
        }
    }
}
