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
        
        //TODO: do tracking!
        print(SDKConfig.appId)
        print ("TRACKING type:\(type) variables:\(variables) trackId:\(trackId)")
    }
    
    
    
    
    public var flushTimeout:Int {
        get {
            return _flushTimeout ?? EventsTracker.defaultFlushTimeout
        }
        set {
            _flushTimeout = newValue
        }
    }
    public func resetFlushTimeout() {
        _flushTimeout = nil
    }
    
    
    public var flushLimit:Int {
        get {
            return _flushLimit ?? EventsTracker.defaultFlushLimit
        }
        set {
            _flushLimit = newValue
        }
    }
    public func resetFlushLimit() {
        _flushLimit = nil
    }
    
    
    public var baseURL:NSURL {
        get {
            return _baseURL ?? EventsTracker.defaultBaseURL
        }
        set {
            _baseURL = newValue
        }
    }
    public func resetBaseURL() {
        _baseURL = nil
    }
    
    // TODO: implement viewContext
    public var viewContext:ViewContext? = nil
    // TODO: implement campaignContext
    public var campaignContext:CampaignContext? = nil
    
    
    
    // MARK: Private (instance)
    private var _flushTimeout:Int?
    private var _flushLimit:Int?
    private var _baseURL:NSURL?
    
    
    
    
    
    
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
    
    public static var defaultFlushTimeout:Int {
        get {
            return _overrideDefaultFlushTimeout ?? _defaultFlushTimeout
        }
        set {
            _overrideDefaultFlushTimeout = newValue
        }
    }
    public static func resetDefaultFlushTimeout() {
        _overrideDefaultFlushTimeout = nil
    }
    
    
    public static var defaultFlushLimit:Int {
        get {
            return _overrideDefaultFlushLimit ?? _defaultFlushLimit
        }
        set {
            _overrideDefaultFlushLimit = newValue
        }
    }
    public static func resetDefaultFlushLimit() {
        _overrideDefaultFlushLimit = nil
    }
    
    
    public static var defaultBaseURL:NSURL {
        get {
            return _overrideDefaultBaseURL ?? _defaultBaseURL
        }
        set {
            _overrideDefaultBaseURL = newValue
        }
    }
    public static func resetDefaultBaseURL() {
        _overrideDefaultBaseURL = nil
    }
    
    
    // TODO: Add static shared viewContext
    // TODO: Add static shared campaignContext
    
    
    // MARK: Private (static)
    
    private static let _globalTrackId : String? = {
        return Utils.fetchInfoPlistValue("TrackId") as? String
    }()
    private static var _overrideTrackId : String? = nil
    
    private static let _defaultFlushTimeout:Int = 30
    private static var _overrideDefaultFlushTimeout:Int?

    private static let _defaultFlushLimit:Int = 200
    private static var _overrideDefaultFlushLimit:Int?
    
    private static let _defaultBaseURL:NSURL = NSURL(string: "events.shopgun.com")!
    private static var _overrideDefaultBaseURL:NSURL?

}
