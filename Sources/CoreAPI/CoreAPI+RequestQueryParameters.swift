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

extension CoreAPI.Requests {
    
    /// How to define how many items to request, and with what item offset
    public struct PaginatedQuery {
        public var startCursor: Int
        public var itemCount: Int
        
        public init(start: Int = 0, count: Int) {
            self.startCursor = start
            self.itemCount = count
        }
        
        internal var requestParams: [String: String] {
            return ["offset": String(self.startCursor),
                    "limit": String(self.itemCount)]
        }
    }
    
    /// How to define a geographic location query constraint
    public struct LocationQuery {
        public var coordinate: CLLocationCoordinate2D
        public var radius: CLLocationDistance?
        public var isFromSensor: Bool
        
        public init(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance?, isFromSensor: Bool) {
            self.coordinate = coordinate
            self.radius = radius
            self.isFromSensor = isFromSensor
        }
        
        internal var requestParams: [String: String] {
            var params: [String: String] = [:]
            
            params["r_lat"] = String(self.coordinate.latitude)
            params["r_lng"] = String(self.coordinate.longitude)
            params["r_sensor"] = self.isFromSensor ? "true" : "false"
            
            if let radius = self.radius {
                params["r_radius"] = String(radius)
            }
            return params
        }
    }
}
