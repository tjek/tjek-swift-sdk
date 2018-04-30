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
    /// This is a concrete implementation of an Event.
    // It defines everything that an event, as seen by the server
    internal class ShippableEvent {
        
        let version: String = "1.0.0"
        
        let type: String
        let trackId: String
        let properties: [String: AnyObject]?
        let uuid: String
        let recordedDate: Date
        let clientId: String
        let includeLocation: Bool
        
        init(type: String,
             trackId: String,
             properties: [String: AnyObject]? = nil,
             uuid: String = UUID().uuidString,
             recordedDate: Date = Date(),
             clientId: String,
             includeLocation: Bool) {
            
            self.type = type
            self.trackId = trackId
            self.properties = properties
            self.uuid = uuid
            self.recordedDate = recordedDate
            self.clientId = clientId
            self.includeLocation = includeLocation
        }
    }
}

// Make the Event work with the pool
extension EventsTracker.ShippableEvent: PoolableObject {
    
    var poolId: String {
        return self.uuid
    }
    
    /// Allow the Event to be converted to a dictionary, for JSONification
    func serialize() -> SerializedPoolObject? {
        
        var dict: [String: AnyObject] = [:]
        
        dict["type"] = type as AnyObject? // required
        
        dict["id"] = uuid as AnyObject // required
        dict["version"] = version as AnyObject  // required
        dict["recordedAt"] = EventsTracker.dateFormatter.string(from: recordedDate) as AnyObject?  // required, but if date is invalid we want server to warn
        
        // client - required
        let clientDict: [String: String] = ["id": clientId, "trackId": trackId]
        dict["client"] = clientDict as AnyObject
        
        // context - required
        let contextDict: [String: AnyObject] = EventsTracker.Context.toDictionary(includeLocation: self.includeLocation) ?? [:]
        dict["context"] = contextDict as AnyObject
        
        // properties - required
        let propertiesDict: [String: AnyObject] = prepareForJSON(properties as AnyObject?) as? [String: AnyObject] ?? [:]
        dict["properties"] = propertiesDict as AnyObject
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return nil
        }
        
        return (poolId, jsonData)
    }
}

/// Given arbitrary properties, this will remove those that cant be converted to JSON values, and parse Dates where appropriate.
fileprivate func prepareForJSON(_ property: AnyObject?) -> AnyObject? {
    
    guard let prop = property else { return nil }
    
    switch prop {
    case is Int,
         is Double, is Float,
         is NSNumber,
         is NSNull,
         is String, is NSString:
        return prop
    case is [AnyObject]:
        var result: [AnyObject]? = nil
        for val in (prop as! [AnyObject]) {
            if let cleanVal = prepareForJSON(val) {
                if result == nil { result = [] }
                result?.append(cleanVal)
            }
        }
        return result as AnyObject?
    case is [String: AnyObject]:
        var result: [String: AnyObject]? = nil
        for (key, val) in (prop as! [String: AnyObject]) {
            if let cleanVal = prepareForJSON(val) {
                if result == nil { result = [:] }
                result?[key] = cleanVal
            }
        }
        return result as AnyObject?
    case is Date:
        return EventsTracker.dateFormatter.string(from: prop as! Date) as AnyObject?
    default:
        return nil
    }
}
