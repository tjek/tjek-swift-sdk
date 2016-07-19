//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit
import ShopGunCore

@objc(SGNEventsTracker)
public class EventsTracker : NSObject {
    
    // MARK: Instance properties & methods
    
    public let trackId:String
    
    public init(trackId:String) {
        self.trackId = trackId
    }
    
//    public func trackEvent(type:String) {
//        trackEvent(type, variables: nil)
//    }
    
    public func trackEvent(type:String, variables:[String:String]?) {
        //TODO: do tracking!
        print ("TRACKING type:\(type) variables:\(variables) trackId:\(trackId)")
    }
    
    // TODO: use default static values
    public var flushTimeout:Int {
        return 30
    }
    public var flushLimit:Int {
        return 200
    }
    public var baseURL:NSURL {
        return NSURL(string: "events.shopgun.com")!
    }
    
    public var viewContext:ViewContext? = nil
    public var campaignContext:CampaignContext? = nil
    public var locationContext:LocationContext? = nil
    public var includeLocationContext:Bool = true
    
    
    
    public static var _defaultFlushTimeout:Int?
    public static var defaultFlushTimeout:Int? {
        get {
            return _defaultFlushTimeout ?? 30
        }
        set {
            _defaultFlushTimeout = newValue
        }
    }
    
    
    public static var trackId:String? {
        // TODO: read from infoPlist & allow overriding
        return nil
    }
    
//    public static func trackEvent(type:String, variables:[String:String]? = nil, trackId:String? = EventsTracker.trackId) {
//        
//        guard trackId != nil else {
//            // TODO: more details about how to provide trackId
//            print("You must provide a `trackId` before you perform `trackEvent`")
//            return
//        }
//        
//        let tracker = EventsTracker(trackId: trackId!)
//        tracker.trackEvent(type, variables: variables)
//    }
    
    
    
}
