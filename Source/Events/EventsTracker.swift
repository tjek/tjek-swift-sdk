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
        trackEvent(type, variables: nil)
    }
    public func trackEvent(type:String, variables:[String:String]?) {
        
//        TODO: do tracking!
//        print(SDKConfig.appId)
        print ("TRACKING type:\(type) variables:\(variables) trackId:\(trackId)")
        
        // build event
        let event = Event(type, trackId:trackId)
        
        // serialize event
        var serializedEvent:SerializedEvent = ["id":event.uuid]
        
        // send serialized event to pool
        EventsTracker._pool.pushEvent(serializedEvent)
    }
    
    
    // TODO: implement viewContext
    public var viewContext:ViewContext? = nil
    // TODO: implement campaignContext
    public var campaignContext:CampaignContext? = nil
    
    
    
    
    
    // MARK: - Static properties & methods
    
    
    public static func trackEvent(type:String, variables:[String:String]? = nil, trackId:String? = EventsTracker.trackId) {

        guard trackId != nil else {
            // TODO: more details about how to provide trackId
            print("You must provide a `trackId` before you perform `trackEvent`")
            return
        }

        let tracker = EventsTracker(trackId: trackId!)
        tracker.trackEvent(type, variables: variables)
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
        let pool = EventsPool(flushTimeout:30, flushLimit:200) { events, completion in
            
//            
//            // build json dictionary to ship
//            let jsonDict:JSONDict = ["version": version,
//                                     "events": eventDicts]
//            
//            
//            // TODO: move to another class?
//            let request = NSMutableURLRequest(URL:NSURL(string:"events.shopgun.com/track")!)
//            request.HTTPMethod = "POST"
//            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//            request.addValue("application/json", forHTTPHeaderField: "Accept")
//            
//            request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(jsonDict, options:[])
//            
//            
//            let task = networkSession.dataTaskWithRequest(request) {
//                data, response, error in
//                
//            }
//            task.resume()

            
            // actually do the shipping of the events
            print ("> Shipping \(events.count) events...")
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(8 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                
                var response:[String:EventShipperResponseStatus] = [:]
                for serializedEvent in events {
                    response[serializedEvent["id"] as! String] = EventShipperResponseStatus.ack
                }
                
                completion(eventIdStatuses: response)
            }
        }
        
        
        
        return pool
    }()
}
