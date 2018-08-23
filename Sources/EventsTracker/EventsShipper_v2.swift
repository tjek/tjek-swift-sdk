//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

struct ShippableEvent: Codable {
    var id: String
    var version: Int
    var timestamp: Date
    var object: JSONValue
}

extension ShippableEvent {
    init?(event: Event) {
        // convert the event into a JSONValue object
        guard let data = try? JSONEncoder().encode(event),
            let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: data) else {
                return nil
        }
        
        self.init(id: event.id.rawValue,
                  version: event.version,
                  timestamp: event.timestamp,
                  object: jsonValue)
    }
}

extension ShippableEvent: CacheableEvent {
    var cacheId: String { return id }
}

enum EventShipperResult {
    case success
    case error
    case retry
}

struct EventsShipper_v2 {
    
    let baseURL: URL
    let endpoint: String = "sync"
    let dryRun: Bool
    let networkSession: URLSession
    let maxAge: TimeInterval
    
    init(baseURL: URL, dryRun: Bool = false, maxAge: TimeInterval = 60*60*36, networkSession: URLSession = URLSession(configuration: URLSessionConfiguration.default)) {
        self.baseURL = baseURL
        self.dryRun = dryRun
        self.maxAge = maxAge
        self.networkSession = networkSession
    }
    
    func ship(events: [ShippableEvent], completion: @escaping ([String: EventShipperResult]) -> Void) {
        EventsShipper_v2.ship(events: events,
                              url: self.baseURL.appendingPathComponent(self.endpoint),
                              maxAge: self.maxAge,
                              networkSession: self.networkSession,
                              dryRun: self.dryRun,
                              completion: completion)
    }
    
    static func ship(events: [ShippableEvent], url: URL, maxAge: TimeInterval, networkSession: URLSession, dryRun: Bool, completion: @escaping ([String: EventShipperResult]) -> Void) {
        
        //eject if in dryRun mode
        guard dryRun == false else {
            completion(
                events.reduce(into: [:]) { result, event in
                    result[event.id] = .success
                }
            )
            return
        }
        
        let (data, initialResults) = prepareRequestData(events: events)
        
        guard let jsonData = data else {
            completion(initialResults)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        // actually do the shipping of the events
        let task = networkSession.dataTask(with: request) { (data, response, error) in
            let results = parseShipperResponse(shippedEvents: events,
                                               initialResults: initialResults,
                                               maxAge: maxAge,
                                               statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                               responseData: data)
            completion(results)
        }
        
        task.resume()
    }
    
    static func prepareRequestData(events: [ShippableEvent]) -> (Data?, [String: EventShipperResult]) {
        // TODO: shipping context
        //        "application": {
        //            "id": "AAAhWQ==",                    // id is the same as you use in your events.
        //            // this is used to identify the application for debugging purposes,
        //            // even if all events in the events list are invalid.
        //            "build": 2001003180,                 // an integer describing your applications build number.
        //            // new versions of the build should have a build number strictly higher than versions that came before it.
        //            "name": "ShopGun iOS (SDK 2.4.1)"   // A friendly label for the current version of your application.
        //            // It should indicate what application we are dealing with.
        //            // It can duplicate information also contained in the build number,
        //            // if this is helpful for debugging. like, "Bilka iOS (sdk 2.5)"
        //        },
        // place array of dictionaries under 'events' key
        let jsonDict: [String: [JSONValue]] = ["events": events.map { $0.object }]
        
        // convert the objects to json
        guard let jsonData = try? JSONEncoder().encode(jsonDict) else {
            return (nil, events.reduce(into: [:]) { $0[$1.id] = .error })
        }
        
        return (jsonData, [:])
    }
    
    /**
     Parse the response from the `/sync` endpoint. If unable to parse, uses the `shippedEvents` to.
     */
    static func parseShipperResponse(shippedEvents: [ShippableEvent], initialResults: [String: EventShipperResult], maxAge: TimeInterval, statusCode: Int, responseData: Data?) -> [String: EventShipperResult] {
        // try to parse the response from the server.
        // if it is unreadable we will just tell pool to remove just the non-event objects
        guard
            (200 ..< 300).contains(statusCode),
            let data = responseData,
            let eventsResponse = (try? JSONDecoder().decode(EventShipperResponse.self, from: data))
            else {
                // Unable to parse the server response - mark all the to-be-shipped events as needing to be retried
                return shippedEvents.reduce(into: initialResults) { (result, event) in
                    if event.timestamp.timeIntervalSinceNow < -maxAge {
                        result[event.id] = .error
                    } else {
                        result[event.id] = .retry
                    }
                }
        }
        
        return eventsResponse.events.reduce(into: initialResults) { (result, eventResponse) in
            result[eventResponse.id] = {
                switch eventResponse.status {
                case .ack:
                    // Server successfully acknowledged the event
                    return .success
                case .nack:
                    // find the date of the event that `nack`'d, and check if it's too old.
                    let eventDate = shippedEvents.first(where: { $0.id == eventResponse.id })?.timestamp ?? .distantPast
                    if eventDate.timeIntervalSinceNow < -maxAge {
                        // if the server is unable to acknowledge the event, and the event is too old, then error
                        return .error
                    } else {
                        // if the server is unable to acknowledge the event (but isnt erroring), then retry
                        return .retry
                    }
                case .validationError,
                     .unknown:
                    // if we recieve a status we do not understand, consider it an error
                    return .error
                }
            }()
        }
    }
}

struct EventShipperResponse: Decodable {
    var events: [ShippedEvent]
    
    struct ShippedEvent: Decodable {
        var id: String
        var status: Status
        var errors: [ShipError]
        
        struct ShipError: Decodable {
            var type: String
            var path: [String]?
        }
        
        enum Status: RawRepresentable, Decodable {
            case ack
            case nack
            case validationError
            case unknown(String)
            
            var rawValue: String {
                switch self {
                case .ack: return "ack"
                case .nack: return "nack"
                case .validationError: return "validation_error"
                case .unknown(let raw): return raw
                }
            }
            
            init?(rawValue: String) {
                self = [.ack, .nack, .validationError]
                    .first { $0.rawValue == rawValue.lowercased() } ?? .unknown(rawValue.lowercased())
            }
        }
    }
}
