///
///  Copyright (c) 2018 Tjek. All rights reserved.
///
#if canImport(CoreLocation)
import Foundation
import CoreLocation

extension TjekEventsTracker.Context {
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
#endif
