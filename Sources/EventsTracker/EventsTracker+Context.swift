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

extension EventsTracker {
    
    struct Context {
        
        static func toDictionary(includeLocation: Bool) -> [String: AnyObject]? {
            var dict = [String: AnyObject]()
            
            dict["userAgent"] = userAgent() as AnyObject
            
            if includeLocation {
                dict["location"] = LocationContext.toDictionary() as AnyObject?
            }
            
            return dict
        }
        
        struct LocationContext {
            
            static var locationManager: CLLocationManager = {
                return CLLocationManager()
            }()
            
            static var location: CLLocation? {
                let authStatus = CLLocationManager.authorizationStatus()
                guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
                    return nil
                }
                
                return locationManager.location
            }
            
            static func toDictionary() -> [String: AnyObject]? {
                
                if let location = self.location,
                    (-90.0 ... 90.0).contains(location.coordinate.latitude),
                    (-180.0 ... 180.0).contains(location.coordinate.longitude) {
                    
                    var dict = [String: AnyObject]()
                    
                    dict["determinedAt"]  = EventsTracker.dateFormatter.string(from: location.timestamp) as AnyObject?
                    dict["latitude"] = location.coordinate.latitude as AnyObject // required
                    dict["longitude"] = location.coordinate.longitude as AnyObject // required
                    dict["altitude"] = location.altitude as AnyObject?
                    dict["speed"] = location.speed >= 0 ? (location.speed as AnyObject?) : nil
                    dict["accuracy"] = ["horizontal": location.horizontalAccuracy,
                                        "vertical": location.verticalAccuracy] as AnyObject?
                    dict["floor"] = location.floor?.level as AnyObject?
                    
                    return dict
                } else {
                    return nil
                }
            }
        }
    }
}
