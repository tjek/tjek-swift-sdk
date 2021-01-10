//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import CoreLocation

extension EventsTracker.Context {
    public mutating func updateLocation(coordinate: CLLocationCoordinate2D, timestamp: Date) {
        self.updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude, timestamp: timestamp)
    }
    
    public mutating func updateLocation(_ location: CLLocation?) {
        if let location = location {
            self.updateLocation(coordinate: location.coordinate, timestamp: location.timestamp)
        } else {
            self.clearLocation()
        }
    }
}
