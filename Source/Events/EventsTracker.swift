//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation



@objc(SGNEventsTracker)
public class EventsTracker : NSObject {
    
    // MARK: Instance properties & methods
    
    public let trackId:String
    
    public init(trackId:String) {
        self.trackId = trackId
    }
    
    public func trackEvent(type:String) {
        trackEvent(type, properties: nil)
    }
    public func trackEvent(type:String, properties:[String:AnyObject]?) {
        if let serializedEvent = EventsTracker.buildSerializedEvent(type, trackId:trackId, properties:properties, viewContext:_currentViewContext, campaignContext:_currentCampaignContext) {
            EventsTracker._pool.pushEvent(serializedEvent)
        }
    }
    
    
    
    public func updateView(path:[String]? = nil, uri:String? = nil, previousPath:[String]? = nil) {
        
        if path == nil && previousPath == nil && uri == nil {
            _currentViewContext = nil
        }
        else {
            _currentViewContext = Context.ViewContext(path:path, previousPath: previousPath, uri: uri)
        }
    }
    
    
    public func updateCampaign(name:String? = nil, source:String? = nil, medium:String? = nil, term:String? = nil, content:String? = nil) {
        if name == nil && source == nil && medium == nil && term == nil && content == nil {
            _currentCampaignContext = nil
        } else {
            _currentCampaignContext = Context.CampaignContext(name:name, source: source, medium: medium, term: term, content: content)
        }
    }
    
    
    
    
    
    
    // MARK: - Static properties & methods
    
    public static var sharedTracker:EventsTracker? {
        if _sharedTracker == nil,
            let trackId = _overrideTrackId ?? _globalTrackId {
            _sharedTracker = EventsTracker(trackId: trackId)
        }
        
        return _sharedTracker
    }
    
    
    public static var trackId:String? {
        get {
            return _sharedTracker?.trackId
        }
        set {
            _overrideTrackId = newValue
            _sharedTracker = nil
        }
    }
    
    
    public static func trackEvent(type:String) {
        trackEvent(type, properties: nil)
    }
    public static func trackEvent(type:String, properties:[String:AnyObject]?) {
        sharedTracker?.trackEvent(type, properties: properties)
    }
    
    
    
    // MARK: Property defaults
    
    public static var flushTimeout:Int {
        get { return _pool.flushTimeout }
        set { _pool.flushTimeout = newValue }
    }
    public static var flushLimit:Int {
        get { return _pool.flushLimit }
        set { _pool.flushLimit = newValue }
    }
    
    public static var baseURL:NSURL = NSURL(string: "https://events.shopgun.com")!
    
    
    
    // MARK: Private (static)
    
    private static var _sharedTracker:EventsTracker?
    
    
    private static let _globalTrackId : String? = {
        return Utils.fetchInfoPlistValue("TrackId") as? String
    }()
    private static var _overrideTrackId : String? = nil
    
    
    private var _currentViewContext:Context.ViewContext?
    private var _currentCampaignContext:Context.CampaignContext?
    
    
    
    
    private static var _pool:EventsPool = {
        let pool = EventsPool(flushTimeout:30, flushLimit:200) { (serializedEvents, completion) in
            
            
            
            var modifiedEvents = serializedEvents.map { (event:SerializedEvent) -> SerializedEvent in
                
                var modifiedEvent = event
                modifiedEvent["sentAt"] = Utils.ISO8601_dateFormatter.stringFromDate(NSDate())
                
                return modifiedEvent
            }
            
            
            
            // build json dictionary to ship. serializedEvents is in the format that was posted to the pool
            let jsonDict = ["events": modifiedEvents]
            
            
            let url:NSURL? = baseURL.URLByAppendingPathComponent("track")
            
            let request = NSMutableURLRequest(URL:url!)
            request.HTTPMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
                
            if let jsonData = try? NSJSONSerialization.dataWithJSONObject(jsonDict, options:[]) {
                request.HTTPBody = jsonData
            } else {
                // unable to serialize jsonDict... EJECT!
                completion(shippedEventIds: nil)
                return
            }
            
            // actually do the shipping of the events
            let task = networkSession.dataTaskWithRequest(request) {
                data, response, error in
                
                
                if data != nil,
                    let jsonData = try? NSJSONSerialization.JSONObjectWithData(data!, options:[]) as? [String:AnyObject],
                    let events = jsonData!["events"] as? [[String:AnyObject]] {
                    
                    var shippedEventIds:[String] = []
                    
                    for eventData:[String:AnyObject] in events {
                        if let uuid = eventData["id"] as? String,
                            let status = eventData["status"] as? String {
                            
                            // status is 'nack'
                            if status != "nack" {
                                shippedEventIds.append(uuid)
                                
                                // TODO: count failures? log errors?
//                                if status != "ack" {
//                                    print ("ship error: \(eventData)")
//                                }
                            }
                        }
                    }
                    completion(shippedEventIds: shippedEventIds)
                } else {
                    completion(shippedEventIds: nil)
                }
            }
            task.resume()
        }
        
        return pool
    }()
    
    
    private static let networkSession:NSURLSession = {
        return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    }()
    
    
    
    // TODO: move this to an Event struct that conforms to serializable protocol?
    private static func buildSerializedEvent(type:String, trackId:String, properties:[String:AnyObject]? = nil, uuid:String = NSUUID().UUIDString, recordedDate:NSDate = NSDate(), clientId:String = SDKConfig.clientId, viewContext:Context.ViewContext? = nil, campaignContext:Context.CampaignContext? = nil) -> SerializedEvent? {
        
        var event = [String:AnyObject]()
        
        event["version"] = "1.0.0" //Modify this when event's structure changes
        event["id"] = uuid
        event["type"] = type
        event["recordedAt"] = Utils.ISO8601_dateFormatter.stringFromDate(recordedDate)
        
        // client
        event["client"] = ["id": clientId,
                           "trackId": trackId]
        
        // properties
        if properties != nil {
            event["properties"] = cleanProperties(properties!)
        }
        
        // context
        event["context"] = Context.toDictionary(viewContext, campaignContext:campaignContext)
        
        return event
    }
    
    
    // given some properties that were passed to the EventsTracker, remove those that cant be converted to JSON values
    // TODO: nicer way?
    private static func cleanProperties(prop:AnyObject)->AnyObject? {
        
        switch prop {
        case is Int,
             is Double,
             is Float,
             is NSNull,
             is String:
            return prop
        case is Array<AnyObject>:
            var result:[AnyObject]? = nil
            for val in (prop as! Array<AnyObject>) {
                if let cleanVal = cleanProperties(val) {
                    if result == nil { result = [] }
                    result?.append(cleanVal)
                }
            }
            return result
        case is Dictionary<String,AnyObject>:
            var result:[String:AnyObject]? = nil
            for (key, val) in (prop as! Dictionary<String,AnyObject>) {
                if let cleanVal = cleanProperties(val) {
                    if result == nil { result = [:] }
                    result?[key] = cleanVal
                }
            }
            return result
        case is NSDate:
            return Utils.ISO8601_dateFormatter.stringFromDate(prop as! NSDate)
        default:
            return nil
        }
    }
    
}

