//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation

import CoreLocation

@objc(SGNLocationContext)
public class LocationContext : NSObject {
    
    static func fetchCurrentUserLocation()-> CLLocation? {
        let authStatus = CLLocationManager.authorizationStatus()
        guard (authStatus == .AuthorizedWhenInUse || authStatus == .AuthorizedAlways) else {
            return nil
        }
        
        return CLLocationManager().location
    }
}
