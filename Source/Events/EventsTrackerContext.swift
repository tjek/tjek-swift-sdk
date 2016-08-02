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
import CoreLocation



protocol SerializableContext {
    static func toDictionary() -> [String:AnyObject]?
}

extension EventsTracker {
    
    struct Context {
        
        static func toDictionary(viewContext:ViewContext?, campaignContext:CampaignContext?) -> [String:AnyObject]? {
            var dict = [String:AnyObject]()
            
            dict["application"] = ApplicationContext.toDictionary()
            dict["device"] = DeviceContext.toDictionary()
            dict["os"] = OperatingSystemContext.toDictionary()
            dict["location"] = LocationContext.toDictionary()
            dict["locale"] = locale
            dict["timezone"] = TimeZoneContext.toDictionary()
            dict["userAgent"] = userAgent
            
            dict["session"] = ["id": SDKConfig.sessionId]
            dict["view"] = viewContext?.toDictionary()
            dict["campaign"] = campaignContext?.toDictionary()
            
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
        
        
        struct ViewContext {
            var path:[String]?
            var previousPath:[String]?
            var uri:String?
            
            func toDictionary() -> [String:AnyObject]? {
                guard path != nil else {
                    return nil
                }
                
                var dict = [String:AnyObject]()
                dict["path"]  = path
                dict["previousPath"] = previousPath
                dict["uri"] = uri
                return dict.count > 0 ? dict : nil
            }
        }
        
        struct CampaignContext {
            var name:String?
            var source:String?
            var medium:String?
            var term:String?
            var content:String?
            
            func toDictionary() -> [String:AnyObject]? {
                var dict = [String:AnyObject]()
                dict["name"]  = name
                dict["source"] = source
                dict["medium"] = medium
                dict["term"] = term
                dict["content"] = content
                return dict.count > 0 ? dict : nil
            }
        }
        
        
        
        struct ApplicationContext : SerializableContext {
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
        
        struct DeviceContext : SerializableContext {
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
        
        
        struct OperatingSystemContext : SerializableContext {
            
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
        
        
        struct TimeZoneContext : SerializableContext {
            
            static var utcOffsetSeconds:Int {
                return NSTimeZone.localTimeZone().secondsFromGMT
            }
            
            static func toDictionary() -> [String:AnyObject]? {
                var dict = [String:AnyObject]()
                dict["utcOffsetSeconds"]  = utcOffsetSeconds
                return dict
            }
        }
        
        struct LocationContext : SerializableContext {
            static var location:CLLocation? {
                let authStatus = CLLocationManager.authorizationStatus()
                guard (authStatus == .AuthorizedWhenInUse || authStatus == .AuthorizedAlways) else {
                    return nil
                }
                
                return CLLocationManager().location
            }
            
            static func toDictionary() -> [String:AnyObject]? {
                
                if let location = self.location {
                    
                    var dict = [String:AnyObject]()
                    
                    dict["determinedAt"]  = Utils.ISO8601_dateFormatter.stringFromDate(location.timestamp)
                    dict["latitude"] = location.coordinate.latitude
                    dict["longitude"] = location.coordinate.longitude
                    dict["altitude"] = location.altitude
                    dict["speed"] = location.speed
                    dict["accuracy"] = ["horizontal":location.horizontalAccuracy,
                                        "vertical":location.verticalAccuracy]
                    dict["floor"] = location.floor?.level
                    
                    return dict
                } else {
                    return nil
                }
            }
        }
    }
    
}
