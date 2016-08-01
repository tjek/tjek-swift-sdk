//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation
import UIKit

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
        
        // send serialized event to pool
        if let serializedEvent = EventsTracker.buildSerializedEvent(type, trackId:trackId, properties:properties) {
            EventsTracker._pool.pushEvent(serializedEvent)
        }
    }
    
    
    // TODO: implement viewContext
    public var viewContext:ViewContext? = nil
    // TODO: implement campaignContext
    public var campaignContext:CampaignContext? = nil
    
    
    
    
    
    // MARK: - Static properties & methods
    
    
    public static func trackEvent(type:String, properties:[String:AnyObject]? = nil, trackId:String? = EventsTracker.trackId) {

        guard trackId != nil else {
            // TODO: more details about how to provide trackId
            print("You must provide a `trackId` before you perform `trackEvent`")
            return
        }

        let tracker = EventsTracker(trackId: trackId!)
        tracker.trackEvent(type, properties: properties)
    }
    
    
    
    public static var trackId:String? {
        get {
            if let trackId = _overrideTrackId ?? _globalTrackId {
                return trackId
            }
            
            // TODO: more details in error message.
            print("You must define a ShopGun `appId` in your info.plist or SDKConfig")
            return nil
        }
        set {
            _overrideTrackId = newValue
        }
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
    
    
    public static var baseURL:NSURL {
        get {
            return _overrideBaseURL ?? _defaultBaseURL
        }
        set {
            _overrideBaseURL = newValue
        }
    }
    public static func resetBaseURL() {
        _overrideBaseURL = nil
    }
    
    
    // TODO: Add static shared viewContext
    // TODO: Add static shared campaignContext
    
    
    // MARK: Private (static)
    
    private static let _globalTrackId : String? = {
        return Utils.fetchInfoPlistValue("TrackId") as? String
    }()
    private static var _overrideTrackId : String? = nil
    
    
    private static let _defaultBaseURL:NSURL = NSURL(string: "events.shopgun.com")!
    private static var _overrideBaseURL:NSURL?
    
    private static var _pool:EventsPool = {
        let pool = EventsPool(flushTimeout:30, flushLimit:200) { (serializedEvents, completion) in
            
            
            
            var modifiedEvents = serializedEvents.map { (event:SerializedEvent) -> SerializedEvent in
                
                var modifiedEvent = event
                modifiedEvent["sentAt"] = EventsTracker.ISO8601_dateFormatter.stringFromDate(NSDate())
                
                return modifiedEvent
            }
            
            
            
            // build json dictionary to ship. serializedEvents is in the format that was posted to the pool
            let jsonDict = ["events": modifiedEvents]
            
            
            let url = baseURL.URLByAppendingPathComponent("track")
            
            let request = NSMutableURLRequest(URL:url)
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
            print ("> Shipping \(serializedEvents.count) events...")
            
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
                    print("< Shipped \(shippedEventIds.count) events!")
                    completion(shippedEventIds: shippedEventIds)
                } else {
                    print("< Shipping error :( ", error)
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
    
    
    
    
    private static func buildSerializedEvent(type:String, trackId:String, properties:[String:AnyObject]? = nil, uuid:String = NSUUID().UUIDString, recordedDate:NSDate = NSDate(), clientId:String = SDKConfig.clientId) -> SerializedEvent? {
        
        var event = [String:AnyObject]()
        
        event["version"] = "1.0.0" //Modify this when event's structure changes
        event["id"] = uuid
        event["type"] = type
        event["recordedAt"] = ISO8601_dateFormatter.stringFromDate(recordedDate)
        
        // client
        event["client"] = ["id": clientId,
                           "trackId": trackId]
        
        // properties
        if properties != nil {
            event["properties"] = cleanProperties(properties!)
        }
        
        event["context"] = Context.toDictionary()
        
        return event
    }
    
    
    // given some properties that were passed to the EventsTracker, remove those that cant be converted to JSON values
    // TODO: nicer way? auto-convert NSDate?
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
        default:
            return nil
        }
    }
    
    private static let ISO8601_dateFormatter:NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter
    }()    
}






protocol ContextGenerator {
    static func toDictionary() -> [String:AnyObject]?
}
struct Context : ContextGenerator{
    
    
    static func toDictionary() -> [String:AnyObject]? {
        var dict = [String:AnyObject]()
        
        dict["application"] = ApplicationContext.toDictionary()
        dict["device"] = DeviceContext.toDictionary()
        dict["os"] = OperatingSystemContext.toDictionary()
//        dict["network"] = nil
//        dict["location"] = nil
        dict["locale"] = locale
        dict["timezone"] = OperatingSystemContext.toDictionary()
        dict["userAgent"] = userAgent
        
//        dict["session"] = nil
//        dict["view"] = nil
//        dict["campaign"] = nil
        
        return dict
    }
    
    
    static var locale:String {
        return NSLocale.autoupdatingCurrentLocale().localeIdentifier
    }
    
    static let userAgent:String = {
        let sdkBundleId = "com.shopgun.ios.sdk"
        
        var userAgent = sdkBundleId
        
        if let sdkVersion = NSBundle(identifier: sdkBundleId)?.infoDictionary!["CFBundleShortVersionString"] as? String {
            userAgent = userAgent.stringByAppendingFormat("/%@", sdkVersion)
        }
        
        if let appBundleId = NSBundle.mainBundle().bundleIdentifier {
            userAgent = userAgent.stringByAppendingFormat("(%@", appBundleId)
            if let appVersion = ApplicationContext.version {
                userAgent = userAgent.stringByAppendingFormat("/%@", appVersion)
            }
            userAgent = userAgent.stringByAppendingString(")")
        }
        
        return userAgent
    }()
    
    struct ApplicationContext : ContextGenerator {
        /*
         "name": "Shopgun iOS (beta)",
         "version": "19.0.1",
         "build": "2.0.1-43123-beta"
         */
        static let name:String? = {
            let bundle = NSBundle.mainBundle()
            
            if let name = bundle.objectForInfoDictionaryKey("CFBundleDisplayName") as? String {
                return name
            }
            else if let name = bundle.objectForInfoDictionaryKey("CFBundleName") as? String {
                return name
            }
            else if let name = bundle.objectForInfoDictionaryKey("CFBundleExecutable") as? String {
                return name
            }
            else {
                return nil
            }
        }()
        
        static let version:String? = {
            return NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as? String
        }()
        
        static let build:String? = {
            return NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as? String
        }()
        
        
        static func toDictionary() -> [String:AnyObject]? {
            var dict = [String:AnyObject]()
            dict["name"]  = name
            dict["version"] = version
            dict["build"] = build
            return dict.count > 0 ? dict : nil
        }
    }
    
    struct DeviceContext : ContextGenerator {
        static let manufacturer:String = "Apple"
        
        /// eg. "iPhone7,2"
        static let model:String? = {
            return UIDevice.currentDevice().model
        }()
        // The _native_ size, in absolute px. Always portrait.
        static var screenSize:CGSize {
            return UIScreen.mainScreen().nativeBounds.size
        }

        static func toDictionary() -> [String:AnyObject]? {
            var dict = [String:AnyObject]()
            dict["manufacturer"]  = manufacturer
            dict["model"] = model
            dict["screen"] = ["height":screenSize.height,
                              "width":screenSize.width]
            
            return dict
        }
    }
    
    
    struct OperatingSystemContext : ContextGenerator {
        
        static let name:String = {
            #if os(iOS)
                return "iOS"
            #elseif os(watchOS)
                return "watchOS"
            #elseif os(tvOS)
                return "tvOS"
            #elseif os(OSX)
                return "macOS"
            #elseif os(Linux)
                return "Linux"
            #else
                return "Unknown"
            #endif
        }()
        
        static let version:String = {
            return UIDevice.currentDevice().systemVersion
        }()
        
        static func toDictionary() -> [String:AnyObject]? {
            var dict = [String:AnyObject]()
            dict["name"]  = name
            dict["version"] = version
            return dict
        }
    }
    
    
    struct TimeZoneContext : ContextGenerator {
        
        static var utcOffsetSeconds:Int {
            return NSTimeZone.localTimeZone().secondsFromGMT
        }
        
        static func toDictionary() -> [String:AnyObject]? {
            var dict = [String:AnyObject]()
            dict["utcOffsetSeconds"]  = utcOffsetSeconds
            return dict
        }
    }

}










