///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

public struct LocationQuery: Equatable {
    public var coordinate: Coordinate
    /// In Meters
    public var maxRadius: Int? = nil
    
    public init(coordinate: Coordinate, maxRadius: Int? = nil) {
        self.coordinate = coordinate
        self.maxRadius = maxRadius
    }
}
