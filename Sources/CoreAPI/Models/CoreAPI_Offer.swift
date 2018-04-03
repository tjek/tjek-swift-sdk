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
        
        public var publication: (id: CoreAPI.PagedPublication.Identifier, pageIndex: Int)?
        public var dealerId: CoreAPI.Dealer.Identifier?
        /// The id of the nearest store. Only available if a location was provided when fetching the offer.
        public var storeId: CoreAPI.Store.Identifier?

        // MARK: Equatable
        
        public static func == (lhs: CoreAPI.Offer, rhs: CoreAPI.Offer) -> Bool {
            return lhs.id == rhs.id
                && lhs.heading == rhs.heading
                && lhs.description == rhs.description
                && lhs.images == rhs.images
                && lhs.webshopURL == rhs.webshopURL
                && lhs.runDateRange == rhs.runDateRange
                && lhs.publishDate == rhs.publishDate
                && lhs.price == rhs.price
                && lhs.quantity == rhs.quantity
                && lhs.publication?.id == rhs.publication?.id
                && lhs.publication?.pageIndex == rhs.publication?.pageIndex
                && lhs.dealerId == rhs.dealerId
                && lhs.storeId == rhs.storeId
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
            
            if let imageURLs = try? values.decode(ImageURLSet.CoreAPIImageURLs.self, forKey: .images) {
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
            
            if let catalogId = try? values.decode(CoreAPI.PagedPublication.Identifier.self, forKey: .catalogId),
                let catalogPageNum = try? values.decode(Int.self, forKey: .catalogPage),
                catalogPageNum > 0 {
                self.publication = (id: catalogId, pageIndex: catalogPageNum - 1)
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

        public static func == (lhs: CoreAPI.Offer.Price, rhs: CoreAPI.Offer.Price) -> Bool {
            return lhs.currency == rhs.currency
                && lhs.price == rhs.price
                && lhs.prePrice == rhs.prePrice
        }
    }
    
    public struct Quantity: Decodable, Equatable {
        public var unit: QuantityUnit?
        public var size: (from: Double?, to: Double?)
        public var pieces: (from: Double?, to: Double?)
        
        public static func == (lhs: CoreAPI.Offer.Quantity, rhs: CoreAPI.Offer.Quantity) -> Bool {
            return lhs.unit == rhs.unit
                && lhs.size.from == rhs.size.from
                && lhs.size.to == rhs.size.to
                && lhs.pieces.from == rhs.pieces.from
                && lhs.pieces.from == rhs.pieces.from
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
                self.size = (from: sizeDict["from"], to: sizeDict["to"])
            } else {
                self.size = (from: nil, to:nil)
            }
            
            if let piecesDict = try? values.decode([String: Double].self, forKey: .pieces) {
                self.pieces = (from: piecesDict["from"], to: piecesDict["to"])
            } else {
                self.pieces = (from: nil, to:nil)
            }
        }
    }
    
    public struct QuantityUnit: Decodable, Equatable {
        
        public var symbol: String
        public var siUnit: (symbol: String, factor: Double)
        
        public static func == (lhs: CoreAPI.Offer.QuantityUnit, rhs: CoreAPI.Offer.QuantityUnit) -> Bool {
            return lhs.symbol == rhs.symbol
                && lhs.siUnit.symbol == rhs.siUnit.symbol
                && lhs.siUnit.factor == rhs.siUnit.factor
        }
        
        enum CodingKeys: String, CodingKey {
            case symbol
            case si
        }
        enum SICodingKeys: String, CodingKey {
            case symbol
            case factor
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.symbol = try values.decode(String.self, forKey: .symbol)
            
            let siValues = try values.nestedContainer(keyedBy: SICodingKeys.self, forKey: .si)
            
            let siSymbol = try siValues.decode(String.self, forKey: .symbol)
            let siFactor = try siValues.decode(Double.self, forKey: .factor)
            
            self.siUnit = (siSymbol, siFactor)
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
