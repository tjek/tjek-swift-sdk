///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation
import TjekUtils

/**
 An Event defines a package of data that can be sent to the EventsTracker. There are some core properties that are required, and any additional metadata is added to the `payload`.
 */
public struct Event {
    /// The Identifier type of an Event, using `GenericIdentifier` make sure we dont mix types.
    public typealias Identifier = GenericIdentifier<Event>
    
    /// An Event's payload is defined as a dictionary of JSONValue types.
    public typealias PayloadType = [String: JSONValue]
    
    /// The unique identifier of the event. A UUID string.
    public let id: Identifier
    
    /// The version of the event. If the format of the event ever changes, this may increase. It is used to choose where to send the event, and by the server to decide how to process the event.
    public let version: Int
    
    /// The date the event was triggered.
    public let timestamp: Date
    
    /// The type identifier of the event. There are a set of pre-defined constants that can be used here. For the server to be able to parse the event, the type & payload must be consistent.
    public let type: Int
    
    /// The metadata of the event. A dictionary of JSONValue pairs, with String keys.
    public private(set) var payload: PayloadType
    
    /**
     Creates a new Event.
     - parameter id: The unique identifier of the event. Defaults to a newly generated id.
     - parameter version: The version number if the event's format. Defaults to 2
     - parameter timestamp: The date that the event was triggered. Defaults to the current date.
     - parameter type: The type identifier of the event. You must provide this value.
     - parameter payload: The `payload` metadata to include with the event. Defaults to empty.
     */
    public init(id: Identifier = Identifier.generate(), version: Int = 2, timestamp: Date = Date(), type: Int, payload: PayloadType = [:]) {
        self.id = id
        self.version = version
        self.timestamp = timestamp
        self.type = type
        self.payload = payload
    }
    
    /**
     Merges a new payload into the current one. New values for existing keys will override the old ones (so be careful!).
     - parameter newPayload: The dictionary of JSONValues to merge into the event's payload.
     */
    public mutating func mergePayload(_ newPayload: PayloadType) {
        self.payload.merge(newPayload) { (_, new) in new }
    }
    
}

// MARK: - Equatable

extension Event: Equatable {
    public static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
            && lhs.version == rhs.version
            && lhs.timestamp.eventTimestamp == rhs.timestamp.eventTimestamp
            && lhs.type == rhs.type
            && lhs.payload == rhs.payload
    }
}

// MARK: - Codable

extension Event: Codable {
    
    enum CodingKeys: CodingKey {
        case id
        case version
        case type
        case timestamp
        /// This case defines all unknown payload keys.
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
        
        let payload: [String: JSONValue] = try container.allKeys.reduce(into: [:], { (result, key) in
            // only decode non-known payload keys
            guard case .payload = key else { return }
            
            // decode the key as a JSONValue.
            let value = try container.decode(JSONValue.self, forKey: key)
            
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

// MARK: Event Dates

extension Date {
    var eventTimestamp: Int {
        return Int(timeIntervalSince1970)
    }
    
    init(eventTimestamp: Int) {
        self = .init(timeIntervalSince1970: TimeInterval(eventTimestamp))
    }
}
