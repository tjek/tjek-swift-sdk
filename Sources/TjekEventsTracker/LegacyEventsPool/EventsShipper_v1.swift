///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation
#if !COCOAPODS // Cocoapods merges these modules
import TjekUtils
#endif

/// A class that handles the shipping of the Events
class EventsShipper_v1: PoolShipper_v1Protocol {
    
    /// The dateFormatter of all the dates in/out of the EventsTracker
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return formatter
    }()
    
    var baseURL: URL
    
    /// If true we dont really ship events, just pretend like it was successful
    var dryRun: Bool
    
    init(baseURL: URL, dryRun: Bool = false) {
        self.baseURL = baseURL
        self.dryRun = dryRun
    }
    
    fileprivate static let networkSession: URLSession = {
        return URLSession(configuration: URLSessionConfiguration.default)
    }()
    
    func ship(objects: [SerializedV1PoolObject], completion: @escaping ((_ poolIdsToRemove: [String]) -> Void)) {
        
        var orderedEventDicts: [[String: AnyObject]] = []
        var keyedEventDicts: [String: [String: AnyObject]] = [:]
        
        var allIds: [String] = []
        var idsToRemove: [String] = []
        
        for obj in objects {
            allIds.append(obj.poolId)
            
            // deserialize the jsonData and update the sent date
            if var jsonDict = try? JSONSerialization.jsonObject(with: obj.jsonData, options: []) as? [String: AnyObject] {
                
                jsonDict["sentAt"] = EventsShipper_v1.dateFormatter.string(from: Date()) as AnyObject?
                
                orderedEventDicts.append(jsonDict)
                keyedEventDicts[obj.poolId] = jsonDict
            } else {
                idsToRemove.append(obj.poolId)
            }
        }
        
        //eject if in dryRun mode
        guard dryRun == false else {
            completion(allIds)
            return
        }
        
        // place array of dictionaries under 'events' key
        let jsonDict = ["events": orderedEventDicts]
        
        // convert the objects to json (or msgpack in the future)
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: []) else {
            // unable to serialize jsonDict... tell pool to remove all objects
            completion(allIds)
            return
        }
        
        let url = baseURL.appendingPathComponent("track")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        TjekLogger.debug("[TjekSDK] Shipping \(orderedEventDicts.count) events (\(String(format: "%.3f", Double(jsonData.count) / 1024.0)) kb)")
        
        // actually do the shipping of the events
        let task = EventsShipper_v1.networkSession.dataTask(with: request) { (responseData, response, error) in
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            // try to parse the response from the server.
            // if it is unreadable we will just tell pool to remove just the non-event objects
            guard let data = responseData,
                (200 ..< 300).contains(statusCode),
                let jsonData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
                let events = jsonData["events"] as? [[String: AnyObject]] else {
                    
                    completion(idsToRemove)
                    return
            }
            
            // go through all the returned event statuses, figuring out which can be removed from the pool
            for eventResponse in events {
                if let uuid = eventResponse["id"] as? String,
                    let status = eventResponse["status"] as? String {
                    
                    // if ack then keep id for removal and continue
                    guard status != "ack" else {
                        idsToRemove.append(uuid)
                        continue
                    }
                    
                    // need the event details for posting notification
                    guard let eventDict = keyedEventDicts[uuid] else {
                        idsToRemove.append(uuid)
                        continue
                    }
                    
                    // nack - check the age of the event, and kill it if it's really old
                    if status == "nack" {
                        let maxAge: Double = 60*60*24*7 // 1 week
                        if let recordedDateStr = eventDict["recordedAt"] as? String,
                            let recordedDate = EventsShipper_v1.dateFormatter.date(from: recordedDateStr),
                            recordedDate.timeIntervalSinceNow < -maxAge {
                            
                            idsToRemove.append(uuid)
                            
                            TjekLogger.info("[TjekSDK] Unable to ship event ('\(eventDict["type"] as? String ?? "")'): server responded with 'nack' and event > 7 days old")
                        }
                    } else {
                        // send back all event Ids that were received (even if they were errors)
                        idsToRemove.append(uuid)
                        
                        if let firstError = (eventResponse["errors"] as? [[String: AnyObject]])?.first, let errType = firstError["type"] as? String {
                            
                            let errPath: [String] = firstError["path"] as? [String] ?? []
                            
                            TjekLogger.info("[TjekSDK] Unable to ship event ('\(eventDict["type"] as? String ?? "")'): server responded with '\(status)': \(errType) \(errPath.joined(separator: ", "))")
                        } else {
                            TjekLogger.info("[TjekSDK] Unable to ship event ('\(eventDict["type"] as? String ?? "")'): server responded with '\(status)'")
                        }
                    }
                }
            }
            completion(idsToRemove)
        }
        
        task.resume()
    }
}
