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
public typealias UnitSymbol = String

extension CoreAPI {
    
    public struct Offer: Decodable {
        public typealias Identifier = GenericIdentifier<Offer>
        
        public var id: Identifier
        public var heading: String?
        public var runDateRange: Range<Date>
        public var publishDate: Date?
        
        public var price: Price?
        public var quantity: Quantity?
        
        enum CodingKeys: String, CodingKey {
            case id
            case heading
            case runFromDateStr     = "run_from"
            case runTillDateStr     = "run_till"
            case publishDateStr     = "publish"
            case price              = "pricing"
            case quantity           = "quantity"
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try values.decode(Identifier.self, forKey: .id)
            self.heading = try? values.decode(String.self, forKey: .heading)

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
        }
    }
}

extension CoreAPI.Offer {
    
    public struct Price: Decodable {
        public var currency: CurrencyCode
        public var price: Double
        public var prePrice: Double?
        
        enum CodingKeys: String, CodingKey {
            case currency
            case price
            case prePrice = "pre_price"
        }
    }
    
    public struct Quantity: Decodable {
        public var unit: UnitSymbol?
        public var size: (from: Double?, to: Double?)
        public var pieces: (from: Double?, to: Double?)
        
        enum CodingKeys: String, CodingKey {
            case unit
            case size
            case pieces
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.unit = try? values.decode(UnitSymbol.self, forKey: .unit)
            
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

