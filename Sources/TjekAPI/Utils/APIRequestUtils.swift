///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

/**
 When using location as a parameter in an APIRequest, this defines the position and optional search radius.
 */
public struct LocationQuery: Equatable {
    public var coordinate: Coordinate
    /// In Meters
    public var maxRadius: Int? = nil
    
    public init(coordinate: Coordinate, maxRadius: Int? = nil) {
        self.coordinate = coordinate
        self.maxRadius = maxRadius
    }
}

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

// MARK: - v2 Request Utils

extension LocationQuery {
    public func v2RequestParams() -> [String: String] {
        var params = [
            "r_lat": String(coordinate.latitude),
            "r_lng": String(coordinate.longitude)
        ]
        
        if let radius = maxRadius {
            params["r_radius"] = String(radius)
        }
        return params
    }
}

extension PaginatedRequest {
    public func v2RequestParams() -> [String: String] where CursorType == Int {
        [
            "offset": String(self.startCursor),
            "limit": String(self.itemCount)
        ]
    }
    
    public func v2RequestParams() -> [String: String] where CursorType == String {
        [
            "offset": self.startCursor,
            "limit": String(self.itemCount)
        ]
    }
    
    public func v2RequestParams() -> [String: String] where CursorType == String? {
        [
            "offset": self.startCursor,
            "limit": String(self.itemCount)
        ].compactMapValues({ $0 })
    }
}
