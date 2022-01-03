///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import CoreGraphics
import Foundation
#if !COCOAPODS // Cocoapods merges these modules
import TjekAPI
#endif

public struct PublicationPage_v2: Equatable {
    public var index: Int
    public var title: String?
    public var aspectRatio: Double
    public var images: Set<ImageURL>
}

// MARK: -

public struct HotspotOffer_v2: Equatable {
    
    public typealias ID = OfferId
    
    public var id: ID
    public var heading: String
    public var price: Offer_v2.Price?
    public var quantity: Offer_v2.Quantity?
    public var runDateRange: Range<Date>
    public var publishDate: Date?
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension HotspotOffer_v2: Identifiable { }

extension HotspotOffer_v2: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case heading
        case runFromDateStr     = "run_from"
        case runTillDateStr     = "run_till"
        case publishDateStr     = "publish"
        case price              = "pricing"
        case quantity
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try values.decode(ID.self, forKey: .id)
        self.heading = try values.decode(String.self, forKey: .heading)
        let fromDate = (try? values.decode(Date.self, forKey: .runFromDateStr)) ?? Date.distantPast
        let tillDate = (try? values.decode(Date.self, forKey: .runTillDateStr)) ?? Date.distantFuture
        // make sure range is not malformed
        self.runDateRange = min(tillDate, fromDate) ..< max(tillDate, fromDate)
        
        self.publishDate = try? values.decode(Date.self, forKey: .publishDateStr)
        
        self.price = try? values.decode(Offer_v2.Price.self, forKey: .price)
        self.quantity = try? values.decode(Offer_v2.Quantity.self, forKey: .quantity)
    }
}

// MARK: -

public struct PublicationHotspot_v2: Equatable {
    
    public var offer: HotspotOffer_v2?
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
        
        self.offer = try? values.decode(HotspotOffer_v2.self, forKey: .offer)
        
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
