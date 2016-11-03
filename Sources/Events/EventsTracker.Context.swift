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
        
        static func toDictionary(sessionId:String, personId:String?, viewContext:ViewContext?, campaignContext:CampaignContext?) -> [String:AnyObject]? {
            var dict = [String:AnyObject]()
            
            dict["userAgent"] = userAgent as AnyObject // required
            dict["timeZone"] = TimeZoneContext.toDictionary() as AnyObject?
            dict["locale"] = locale as AnyObject
            
            dict["view"] = viewContext?.toDictionary() as AnyObject?
            dict["session"] = ["id": sessionId] as AnyObject
            dict["location"] = LocationContext.toDictionary() as AnyObject?
            
            dict["os"] = OperatingSystemContext.toDictionary() as AnyObject?
            dict["device"] = DeviceContext.toDictionary() as AnyObject?
            dict["application"] = ApplicationContext.toDictionary() as AnyObject?
            
            dict["campaign"] = campaignContext?.toDictionary() as AnyObject?
            
            dict["personId"] = personId as AnyObject?
            
            return dict
        }
        
        
        static var locale:String {
            return Locale.autoupdatingCurrent.identifier
        }
        
        static let userAgent:String = {
            let sdkBundleId = "com.shopgun.ios.sdk"
            
            var userAgent = sdkBundleId
            
            if let sdkVersion = Bundle(identifier: sdkBundleId)?.infoDictionary!["CFBundleShortVersionString"] as? String {
                userAgent = userAgent.appendingFormat("/%@", sdkVersion)
            }
            
            if let appBundleId = Bundle.main.bundleIdentifier {
                userAgent = userAgent.appendingFormat(" (%@", appBundleId)
                if let appVersion = ApplicationContext.version {
                    userAgent = userAgent.appendingFormat("/%@", appVersion)
                }
                userAgent = userAgent + ")"
            }
            
            return userAgent
        }()
        
        
        struct ViewContext {
            var path:[String]?
            var previousPath:[String]?
            var uri:String?
            
            func toDictionary() -> [String:AnyObject]? {
                var dict = [String:AnyObject]()
                
                dict["path"] = (path != nil && path!.count > 0) ? path as AnyObject? : nil
                dict["previousPath"] = (previousPath != nil && previousPath!.count > 0) ? previousPath as AnyObject? : nil
                dict["uri"] = uri as AnyObject?
                
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
                dict["name"]  = name as AnyObject?
                dict["source"] = source as AnyObject?
                dict["medium"] = medium as AnyObject?
                dict["term"] = term as AnyObject?
                dict["content"] = content as AnyObject?
                return dict.count > 0 ? dict : nil
            }
        }
        
        
        
        struct ApplicationContext : SerializableContext {
            static let name:String? = {
                let bundle = Bundle.main
                
                if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                    return name
                }
                else if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                    return name
                }
                else if let name = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String {
                    return name
                }
                else {
                    return nil
                }
            }()
            
            static let version:String? = {
                return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            }()
            
            static let build:String? = {
                return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            }()
            
            
            static func toDictionary() -> [String:AnyObject]? {
                var dict = [String:AnyObject]()
                dict["name"]  = name as AnyObject?
                dict["version"] = version as AnyObject?
                dict["build"] = build as AnyObject?
                return dict.count > 0 ? dict : nil
            }
        }
        
        struct DeviceContext : SerializableContext {
            static let manufacturer:String = "Apple"
            
            /// eg. "iPhone7,2"
            static let model:String = {
                return UIDevice.current.model
            }()
            // The _native_ size, in absolute px. Always portrait.
            static var screenSize:CGSize {
                return UIScreen.main.nativeBounds.size
            }
            
            static func toDictionary() -> [String:AnyObject]? {
                var dict = [String:AnyObject]()
                dict["manufacturer"]  = manufacturer as AnyObject?
                dict["model"] = model as AnyObject?
                dict["screen"] = ["height":screenSize.height,
                                  "width":screenSize.width] as AnyObject?
                
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
                return UIDevice.current.systemVersion
            }()
            
            static func toDictionary() -> [String:AnyObject]? {
                var dict = [String:AnyObject]()
                dict["name"]  = name as AnyObject
                dict["version"] = version as AnyObject
                return dict
            }
        }
        
        
        struct TimeZoneContext : SerializableContext {
            
            /// The number of seconds from UTC (excluding dst offset)... in DK this is always 3600.
            static var utcOffsetSeconds:Int {
                let secsFromUTC = NSTimeZone.local.secondsFromGMT()
                let dstOffset = Int(NSTimeZone.local.daylightSavingTimeOffset())
                
                return secsFromUTC - dstOffset
            }
            
            /// The number of seconds from UTC (including dst offset)... in DK this is 3600 or 7200.
            static var utcDstOffsetSeconds:Int {
                return NSTimeZone.local.secondsFromGMT()
            }
            
            static func toDictionary() -> [String:AnyObject]? {
                var dict = [String:AnyObject]()
                dict["utcOffsetSeconds"]  = utcOffsetSeconds as AnyObject
                dict["utcDstOffsetSeconds"]  = utcDstOffsetSeconds as AnyObject
                return dict
            }
        }
        
        struct LocationContext : SerializableContext {
            static var location:CLLocation? {
                let authStatus = CLLocationManager.authorizationStatus()
                guard (authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways) else {
                    return nil
                }
                
                return CLLocationManager().location
            }
            
            static func toDictionary() -> [String:AnyObject]? {
                
                if let location = self.location {
                    
                    var dict = [String:AnyObject]()
                    
                    dict["determinedAt"]  = Utils.ISO8601_dateFormatter.string(from: location.timestamp) as AnyObject?
                    dict["latitude"] = location.coordinate.latitude as AnyObject // required
                    dict["longitude"] = location.coordinate.longitude as AnyObject // required
                    dict["altitude"] = location.altitude as AnyObject?
                    dict["speed"] = location.speed as AnyObject?
                    dict["accuracy"] = ["horizontal":location.horizontalAccuracy,
                                        "vertical":location.verticalAccuracy] as AnyObject?
                    dict["floor"] = location.floor?.level as AnyObject?
                    
                    return dict
                } else {
                    return nil
                }
            }
        }
    }
    
}
