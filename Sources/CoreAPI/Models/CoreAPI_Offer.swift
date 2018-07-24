//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public typealias CurrencyCode = String

extension CoreAPI {
    
    public struct Offer: Decodable, Equatable {
        public typealias Identifier = GenericIdentifier<Offer>
        
        public var id: Identifier
        public var heading: String
        public var description: String?
        public var images: ImageURLSet?
        public var webshopURL: URL?
        
        public var runDateRange: Range<Date>
        public var publishDate: Date?
        
        public var price: Price?
        public var quantity: Quantity?
        
        public var branding: Branding?
        
        public var publication: PublicationPageReference?
        public var dealerId: CoreAPI.Dealer.Identifier?
        /// The id of the nearest store. Only available if a location was provided when fetching the offer.
        public var storeId: CoreAPI.Store.Identifier?
        
        public struct PublicationPageReference: Equatable {
            public var id: CoreAPI.PagedPublication.Identifier
            public var pageIndex: Int
        }
        
        // MARK: Decodable
        
        enum CodingKeys: String, CodingKey {
            case id
            case heading
            case description
            case images
            case links
            case runFromDateStr     = "run_from"
            case runTillDateStr     = "run_till"
            case publishDateStr     = "publish"
            case price              = "pricing"
            case quantity
            case branding
            case catalogId          = "catalog_id"
            case catalogPage        = "catalog_page"
            case dealerId           = "dealer_id"
            case storeId            = "store_id"
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try values.decode(Identifier.self, forKey: .id)
            self.heading = try values.decode(String.self, forKey: .heading)
            self.description = try? values.decode(String.self, forKey: .description)
            
            if let imageURLs = try? values.decode(ImageURLSet.CoreAPI.ImageURLs.self, forKey: .images) {
                self.images = ImageURLSet(fromCoreAPI: imageURLs, aspectRatio: nil)
            }
            
            if let links = try? values.decode([String: URL].self, forKey: .links) {
                self.webshopURL = links["webshop"]
            }
            
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
            
            if let publishDateStr = try? values.decode(String.self, forKey: .publishDateStr) {
                self.publishDate = CoreAPI.dateFormatter.date(from: publishDateStr)
            }
            
            self.price = try? values.decode(CoreAPI.Offer.Price.self, forKey: .price)
            self.quantity = try? values.decode(CoreAPI.Offer.Quantity.self, forKey: .quantity)
            
            self.branding = try? values.decode(CoreAPI.Branding.self, forKey: .branding)
            
            if let catalogId = try? values.decode(CoreAPI.PagedPublication.Identifier.self, forKey: .catalogId),
                let catalogPageNum = try? values.decode(Int.self, forKey: .catalogPage),
                catalogPageNum > 0 {
                self.publication = PublicationPageReference(id: catalogId, pageIndex: catalogPageNum - 1)
            }
            
            self.dealerId = try? values.decode(CoreAPI.Dealer.Identifier.self, forKey: .dealerId)
            self.storeId = try? values.decode(CoreAPI.Store.Identifier.self, forKey: .storeId)
        }
    }
}

extension CoreAPI.Offer {
    
    public struct Price: Decodable, Equatable {
        public var currency: CurrencyCode
        public var price: Double
        public var prePrice: Double?
        
        enum CodingKeys: String, CodingKey {
            case currency
            case price
            case prePrice = "pre_price"
        }
    }
    
    public struct Quantity: Decodable, Equatable {
        public var unit: QuantityUnit?
        public var size: QuantityRange
        public var pieces: QuantityRange
        
        public struct QuantityRange: Equatable {
            public var from: Double?
            public var to: Double?
        }
        
        enum CodingKeys: String, CodingKey {
            case unit
            case size
            case pieces
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.unit = try? values.decode(QuantityUnit.self, forKey: .unit)
            
            if let sizeDict = try? values.decode([String: Double].self, forKey: .size) {
                self.size = QuantityRange(from: sizeDict["from"], to: sizeDict["to"])
            } else {
                self.size = QuantityRange(from: nil, to: nil)
            }
            
            if let piecesDict = try? values.decode([String: Double].self, forKey: .pieces) {
                self.pieces = QuantityRange(from: piecesDict["from"], to: piecesDict["to"])
            } else {
                self.pieces = QuantityRange(from: nil, to: nil)
            }
        }
    }
    
    public struct QuantityUnit: Decodable, Equatable {
        
        public var symbol: String
        public var siUnit: SIUnit
        
        public struct SIUnit: Decodable, Equatable {
            public var symbol: String
            public var factor: Double
        }
        
        enum CodingKeys: String, CodingKey {
            case symbol
            case si
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.symbol = try values.decode(String.self, forKey: .symbol)
            self.siUnit = try values.decode(SIUnit.self, forKey: .si)
        }
    }
}

// `offer` (lite) json response
//  {
//        "id": "a8afitUF",
//        "ern": "ern:offer:a8afitUF",
//        "heading": "Gavepapir",
//        "pricing": {
//            "price": 30,
//            "pre_price": null,
//            "currency": "DKK"
//        },
//        "quantity": {
//            "unit": null,
//            "size": {
//                "from": 1,
//                "to": 1
//            },
//            "pieces": {
//                "from": 1,
//                "to": 1
//            }
//        },
//        "run_from": "2018-01-12T23:00:00+0000",
//        "run_till": "2018-01-19T22:59:59+0000",
//        "publish": "2018-01-11T17:00:00+0000"
//    }
