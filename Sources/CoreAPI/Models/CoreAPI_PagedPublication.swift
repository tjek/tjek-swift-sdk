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
    
    /// A `Publication` is a catalog.
    /// If it's type is 'paged' then it has static images for each `Page`, with possible `Hotspot`s referencing `Offer`s on each page, that is published by a `Dealer`.
    /// If it's type is 'incito' then you can use the incito renderer to display it.
    public struct Publication: Decodable, Equatable {
        
        public typealias Identifier = PublicationIdentifier
        
        public enum PublicationType: String, Codable {
            case paged
            case incito
        }
        
        /// The unique identifier of this Publication.
        public var id: Identifier
        /// The name of the publication. eg. "Christmas Special".
        public var label: String?
        /// How many pages this publication has.
        public var pageCount: Int
        /// How many `Offer`s are in this publication.
        public var offerCount: Int
        /// The range of dates that this publication is valid from and until.
        public var runDateRange: Range<Date>
        /// The ratio of width to height for the page-images. So if an image is (w:100, h:200), the aspectRatio is 0.5 (width/height).
        public var aspectRatio: Double
        /// The branding information for the publication's dealer.
        public var branding: Branding
        /// A set of URLs for the different sized images for the cover of the publication.
        public var frontPageImages: ImageURLSet
        /// Whether this publication is available in all stores, or just in a select few stores.
        public var isAvailableInAllStores: Bool
        /// The unique identifier of the dealer that published this publication.
        public var dealerId: CoreAPI.Dealer.Identifier
        /// The unique identifier of the nearest store. This will only contain a value if the `Publication` was fetched with a request that includes store information (eg. one that takes a precise location as a parameter).
        public var storeId: CoreAPI.Store.Identifier?
        
        /// Defines what types of publication this represents.
        /// If it contains `paged`, the `id` can be used to view this in a PagedPublicationViewer
        /// If it contains `incito`, the `id` can be used to view this with the IncitoViewer
        /// If it ONLY contains `incito`, this cannot be viewed in a PagedPublicationViewer (see `isOnlyIncito`)
        public var types: Set<PublicationType>
        
        /// True if this publication can only be viewed as an incito (if viewed in a PagedPublication view it would appear as a single-page pdf)
        public var isOnlyIncito: Bool {
            return types == [.incito]
        }
        
        /// True if this publication can be viewed as an incito
        public var hasIncito: Bool { types.contains(.incito) }
        /// True if this publication can be viewed as an paged publication
        public var hasPagedPublication: Bool { types.contains(.paged) }
        
        public init(
            id: Identifier,
            label: String?,
            pageCount: Int,
            offerCount: Int,
            runDateRange: Range<Date>,
            aspectRatio: Double,
            branding: Branding,
            frontPageImages: ImageURLSet,
            isAvailableInAllStores: Bool,
            dealerId: CoreAPI.Dealer.Identifier,
            storeId: CoreAPI.Store.Identifier?,
            types: Set<PublicationType>
            ) {
            self.id = id
            self.label = label
            self.pageCount = pageCount
            self.offerCount = offerCount
            self.runDateRange = runDateRange
            self.aspectRatio = aspectRatio
            self.branding = branding
            self.frontPageImages = frontPageImages
            self.isAvailableInAllStores = isAvailableInAllStores
            self.dealerId = dealerId
            self.storeId = storeId
            self.types = types
        }
        
        // MARK: Decodable
        
        enum CodingKeys: String, CodingKey {
            case id
            case label              = "label"
            case branding
            case pageCount          = "page_count"
            case offerCount         = "offer_count"
            case runFromDateStr     = "run_from"
            case runTillDateStr     = "run_till"
            case dealerId           = "dealer_id"
            case storeId            = "store_id"
            case availableAllStores = "all_stores"
            case dimensions
            case frontPageImageURLs = "images"
            case types
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
            
            self.isAvailableInAllStores = (try? values.decode(Bool.self, forKey: .availableAllStores)) ?? true
            
            self.dealerId = try values.decode(Dealer.Identifier.self, forKey: .dealerId)
            
            self.storeId = try? values.decode(Store.Identifier.self, forKey: .storeId)

            if let frontPageImageURLs = try? values.decode(ImageURLSet.CoreAPI.ImageURLs.self, forKey: .frontPageImageURLs) {
                self.frontPageImages = ImageURLSet(fromCoreAPI: frontPageImageURLs, aspectRatio: self.aspectRatio)
            } else {
                self.frontPageImages = ImageURLSet(sizedUrls: [])
            }
            
            self.types = (try? values.decode(Set<PublicationType>.self, forKey: .types)) ?? [.paged]
        }
        
        // MARK: -
        
        public struct Page: Equatable {
            public var index: Int
            public var title: String?
            public var aspectRatio: Double
            public var images: ImageURLSet
        }
        
        // MARK: -
        
        public struct Hotspot: Decodable, Equatable {
            
            public var offer: CoreAPI.Offer?
            /// The 0->1 range bounds of the hotspot, keyed by the pageIndex.
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
