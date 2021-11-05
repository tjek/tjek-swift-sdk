///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

public struct Coordinate: Equatable {
    public var latitude: Double
    public var longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

#if canImport(CoreLocation)
import CoreLocation
extension Coordinate {
    public var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    public init(_ clCoordinate: CLLocationCoordinate2D) {
        self.init(latitude: clCoordinate.latitude, longitude: clCoordinate.longitude)
    }
}
#endif
