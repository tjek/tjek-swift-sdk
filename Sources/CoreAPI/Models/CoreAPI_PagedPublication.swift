//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension CoreAPI {
    
    public struct PagedPublication: Decodable {
        
        public typealias Identifier = GenericIdentifier<PagedPublication>
        
        public var id: Identifier
        public var label: String?
        public var pageCount: Int
        public var offerCount: Int
        public var runDateRange: Range<Date>
        public var aspectRatio: Double // (width / height)
        public var branding: Branding
        public var frontPageImages: ImageURLSet
        public var dealerId: CoreAPI.Dealer.Identifier
        
        // MARK: Decodable
        
        //"store_id", "store_url", "dealer_url"
        enum CodingKeys: String, CodingKey {
            case id
            case label
            case branding
            case pageCount          = "page_count"
            case offerCount         = "offer_count"
            case runFromDateStr     = "run_from"
            case runTillDateStr     = "run_till"
            case dealerId           = "dealer_id"
            case dimensions
            case frontPageImageURLs = "images"
        }
  
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try values.decode(Identifier.self, forKey: .id)
            self.label = try? values.decode(String.self, forKey: .label)
            self.branding = try values.decode(Branding.self, forKey: .branding)
            
            self.pageCount = (try? values.decode(Int.self, forKey: .pageCount)) ?? 0
            self.offerCount = (try? values.decode(Int.self, forKey: .offerCount)) ?? 0
            
            var fromDate = Date.distantPast
            if let fromDateStr = try? values.decode(String.self, forKey: .runFromDateStr),
                let from = CoreAPI.dateFormatter.date(from: fromDateStr) {
                fromDate = from
            }
            var tillDate = Date.distantFuture
            if let tillDateStr = try? values.decode(String.self, forKey: .runTillDateStr),
                let till = CoreAPI.dateFormatter.date(from: tillDateStr) {
                tillDate = till
            }
            // make sure range is not malformed
            self.runDateRange = min(tillDate, fromDate) ..< max(tillDate, fromDate)
            
            if let dimDict = try? values.decode([String: Double].self, forKey: .dimensions),
                let width = dimDict["width"], let height = dimDict["height"] {
                
                self.aspectRatio = (width > 0 && height > 0) ? width / height : 1.0
            } else {
                self.aspectRatio = 1.0
            }
            
            self.dealerId = try values.decode(Dealer.Identifier.self, forKey: .dealerId)

            if let frontPageImageURLs = try? values.decode(ImageURLSet.CoreAPIImageURLs.self, forKey: .frontPageImageURLs) {
                self.frontPageImages = ImageURLSet(fromCoreAPI: frontPageImageURLs, aspectRatio: self.aspectRatio)
            } else {
                self.frontPageImages = ImageURLSet(sizedUrls: [])
            }
        }
        
        // MARK: -
        
        public struct Page {
            public var index: Int
            public var title: String?
            public var aspectRatio: Double
            public var images: ImageURLSet
        }
        
        // MARK: -
        
        public struct Hotspot: Decodable, Equatable {
            
            public var offer: CoreAPI.Offer?
            public var pageLocations: [Int: CGRect]
            
            /// This returns a new hotspot whose pageLocation bounds is scaled.
            func withScaledBounds(scale: CGPoint) -> Hotspot {
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
            
            // MARK: Equatable
            
            public static func == (lhs: CoreAPI.PagedPublication.Hotspot, rhs: CoreAPI.PagedPublication.Hotspot) -> Bool {
                return lhs.offer == rhs.offer
                    && lhs.pageLocations == rhs.pageLocations
            }
            
            // MARK: Decoding
            
            enum CodingKeys: String, CodingKey {
                case pageCoords = "locations"
                case offer
            }
            
            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                
                self.offer = try? values.decode(CoreAPI.Offer.self, forKey: .offer)
                
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
    }
}
// MARK: -

extension CoreAPI {
    
    public struct Branding: Decodable {
        public var name: String?
        public var website: URL?
        public var description: String?
        public var logoURL: URL?
        public var color: UIColor?
        
        enum CodingKeys: String, CodingKey {
            case name
            case website
            case description
            case logoURL        = "logo"
            case colorStr       = "color"
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.name = try? values.decode(String.self, forKey: .name)
            self.website = try? values.decode(URL.self, forKey: .website)
            self.description = try? values.decode(String.self, forKey: .description)
            self.logoURL = try? values.decode(URL.self, forKey: .logoURL)
            if let colorStr = try? values.decode(String.self, forKey: .colorStr) {
                self.color = UIColor(hex: colorStr)
            }
        }
    }
}

// `Catalog` json response
//{
//    "id": "6fe6Mg8",
//    "ern": "ern:catalog:6fe6Mg8",
//    "label": "Netto-avisen uge 3 2018",
//    "background": null,
//    "run_from": "2018-01-12T23:00:00+0000",
//    "run_till": "2018-01-19T22:59:59+0000",
//    "page_count": 32,
//    "offer_count": 193,
//    "branding": {
//        "name": "Netto",
//        "website": "http:\/\/netto.dk",
//        "description": "Netto er lig med kvalitetsvarer til lave priser. Det har gjort Netto til en af Danmarks stu00f8rste dagligvareku00e6der.",
//        "logo": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/logo\/default\/00im1ykdf4id12ye.png",
//        "color": "333333",
//        "pageflip": {
//            "logo": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/logo\/pageflip\/00im1ykdql3p4gpl.png",
//            "color": "333333"
//        }
//    },
//    "dealer_id": "9ba51",
//    "dealer_url": "https:\/\/api-edge.etilbudsavis.dk\/v2\/dealers\/9ba51",
//    "store_id": null,
//    "store_url": null,
//    "dimensions": {
//        "height": 1.44773,
//        "width": 1
//    },
//    "images": {
//        "@note.1": "this object contains a single image, used to present a catalog (usually the frontpage)",
//        "thumb": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/catalog\/thumb\/6fe6Mg8-1.jpg?m=p1nyeo",
//        "view": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/catalog\/view\/6fe6Mg8-1.jpg?m=p1nyeo",
//        "zoom": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/catalog\/zoom\/6fe6Mg8-1.jpg?m=p1nyeo"
//    },
//    "pages": {
//        "@note.1": "",
//        "thumb": [],
//        "view": [],
//        "zoom": []
//    },
//    "category_ids": [],
//    "pdf_url": "https:\/\/api-edge.etilbudsavis.dk\/v2\/catalogs\/6fe6Mg8\/download"
//}

// `Pages` response
//[
//    {
//        "thumb": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/catalog\/thumb\/6fe6Mg8-1.jpg?m=p1nyeo",
//        "view": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/catalog\/view\/6fe6Mg8-1.jpg?m=p1nyeo",
//        "zoom": "https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/catalog\/zoom\/6fe6Mg8-1.jpg?m=p1nyeo"
//    }, ...
//]

// `Hotspots` response
//[
//    {
//        "type": "offer",
//        "locations": {
//            "1": [
//                    [ 0.366304, 1.44773 ],
//                    [ 0.366304, 0.6373920871 ],
//                    [ 0.622826, 0.6373920871 ],
//                    [ 0.622826, 1.44773 ]
//            ]
//        },
//        "id": "a8afitUF",
//        "run_from": 1515798000,
//        "run_till": 1516402799,
//        "heading": "Gavepapir",
//        "webshop": null,
//        "offer": {
//            "id": "a8afitUF",
//            "ern": "ern:offer:a8afitUF",
//            "heading": "Gavepapir",
//            "pricing": {
//                "price": 30,
//                "pre_price": null,
//                "currency": "DKK"
//            },
//            "quantity": {
//                "unit": null,
//                "size": {
//                    "from": 1,
//                    "to": 1
//                },
//                "pieces": {
//                    "from": 1,
//                    "to": 1
//                }
//            },
//            "run_from": "2018-01-12T23:00:00+0000",
//            "run_till": "2018-01-19T22:59:59+0000",
//            "publish": "2018-01-11T17:00:00+0000"
//        }
//    }, ...
//]
