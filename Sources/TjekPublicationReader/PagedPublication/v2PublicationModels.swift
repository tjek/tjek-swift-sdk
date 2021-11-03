///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation
import TjekAPI
import CoreGraphics

public struct PublicationPage_v2: Equatable {
    public var index: Int
    public var title: String?
    public var aspectRatio: Double
    public var images: Set<ImageURL>
}

// MARK: -

public struct PublicationHotspot_v2: Equatable {
    
    public var offer: Offer_v2?
    /// The 0->1 range bounds of the hotspot, keyed by the pageIndex.
    public var pageLocations: [Int: CGRect]
    
    /// This returns a new hotspot whose pageLocation bounds is scaled.
    func withScaledBounds(scale: CGPoint) -> PublicationHotspot_v2 {
        var newHotspot = self
        newHotspot.pageLocations = newHotspot.pageLocations.mapValues({
            var bounds = $0
            bounds.origin.x *= scale.x
            bounds.size.width *= scale.x
            bounds.origin.y *= scale.y
            bounds.size.height *= scale.y
            return bounds
        })
        return newHotspot
    }
}

extension PublicationHotspot_v2: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case pageCoords = "locations"
        case offer
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.offer = try? values.decode(Offer_v2.self, forKey: .offer)
        
        if let pageCoords = try? values.decode([Int: [[CGFloat]]].self, forKey: .pageCoords) {
            
            self.pageLocations = pageCoords.reduce(into: [:]) {
                let pageNum = $1.key
                let coordsList = $1.value
                
                guard pageNum > 0 else { return }
                
                let coordRange: (min: CGPoint, max: CGPoint)? = coordsList.reduce(nil, { (currRange, coords) in
                    guard coords.count == 2 else { return currRange }
                    
                    let point = CGPoint(x: coords[0], y: coords[1])
                    
                    guard var newRange = currRange else {
                        return (min: point, max: point)
                    }
                    
                    newRange.max.x = max(newRange.max.x, point.x)
                    newRange.max.y = max(newRange.max.y, point.y)
                    newRange.min.x = min(newRange.min.x, point.x)
                    newRange.min.y = min(newRange.min.y, point.y)
                    
                    return newRange
                })
                
                guard let boundsRange = coordRange else { return }
                
                let bounds = CGRect(origin: boundsRange.min,
                                    size: CGSize(width: boundsRange.max.x - boundsRange.min.x,
                                                 height: boundsRange.max.y - boundsRange.min.y))

                $0[pageNum - 1] = bounds
            }
        } else {
            self.pageLocations = [:]
        }
    }
}
