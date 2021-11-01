///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

public struct LocationQuery {
    public var coordinate: (lat: Double, lng: Double)
    /// In Meters
    public var maxRadius: Int? = nil
    
    public init(coordinate: (lat: Double, lng: Double), maxRadius: Int? = nil) {
        self.coordinate = coordinate
        self.maxRadius = maxRadius
    }
}
