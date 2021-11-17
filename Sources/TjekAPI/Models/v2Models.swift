///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

/// A `Publication` is a catalog, that can be rendered in multiple forms, paged or incito.
public struct Publication_v2: Equatable {
    
    public enum PublicationType: String, Codable, CaseIterable {
        case paged
        case incito
    }
    
    /// The unique identifier of this Publication.
    public var id: PublicationId
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
    public var branding: Branding_v2
    /// A set of URLs for the different sized images for the cover of the publication.
    public var frontPageImages: Set<ImageURL>
    /// Whether this publication is available in all stores, or just in a select few stores.
    public var isAvailableInAllStores: Bool
    /// The unique identifier of the business that published this publication.
    public var businessId: BusinessId
    /// The unique identifier of the nearest store. This will only contain a value if the `Publication` was fetched with a request that includes store information (eg. one that takes a precise location as a parameter).
    public var storeId: StoreId?
    
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
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Publication_v2: Identifiable { }

extension Publication_v2: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case label              = "label"
        case branding
        case pageCount          = "page_count"
        case offerCount         = "offer_count"
        case runFromDateStr     = "run_from"
        case runTillDateStr     = "run_till"
        case businessId           = "dealer_id"
        case storeId            = "store_id"
        case availableAllStores = "all_stores"
        case dimensions
        case frontPageImageURLs = "images"
        case types
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try values.decode(PublicationId.self, forKey: .id)
        self.label = try? values.decode(String.self, forKey: .label)
        self.branding = try values.decode(Branding_v2.self, forKey: .branding)
        
        self.pageCount = (try? values.decode(Int.self, forKey: .pageCount)) ?? 0
        self.offerCount = (try? values.decode(Int.self, forKey: .offerCount)) ?? 0
        
        let fromDate = (try? values.decode(Date.self, forKey: .runFromDateStr)) ?? Date.distantPast
        let tillDate = (try? values.decode(Date.self, forKey: .runTillDateStr)) ?? Date.distantFuture
        // make sure range is not malformed
        self.runDateRange = min(tillDate, fromDate) ..< max(tillDate, fromDate)
        
        if let dimDict = try? values.decode([String: Double].self, forKey: .dimensions),
           let width = dimDict["width"], let height = dimDict["height"] {
            
            self.aspectRatio = (width > 0 && height > 0) ? width / height : 1.0
        } else {
            self.aspectRatio = 1.0
        }
        
        self.isAvailableInAllStores = (try? values.decode(Bool.self, forKey: .availableAllStores)) ?? true
        
        self.businessId = try values.decode(BusinessId.self, forKey: .businessId)
        
        self.storeId = try? values.decode(StoreId.self, forKey: .storeId)
        
        self.frontPageImages = (try? values.decode(v2ImageURLs.self, forKey: .frontPageImageURLs))?.imageURLSet ?? []
                
        self.types = (try? values.decode(Set<PublicationType>.self, forKey: .types)) ?? [.paged]
    }
}

// MARK: -

public struct Branding_v2: Equatable {
    public var name: String?
    public var website: URL?
    public var description: String?
    public var logoURL: URL?
    public var colorHex: String?
    
    public init(name: String?, website: URL?, description: String?, logoURL: URL?, colorHex: String?) {
        self.name = name
        self.website = website
        self.description = description
        self.logoURL = logoURL
        self.colorHex = colorHex
    }
}

extension Branding_v2: Decodable {
    
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
        self.colorHex = try? values.decode(String.self, forKey: .colorStr)
    }
}

#if canImport(UIKit)
import UIKit
extension Branding_v2 {
    public var color: UIColor? {
        colorHex.flatMap(UIColor.init(hex:))
    }
}
#endif

// MARK: -

public struct Offer_v2: Equatable {
    public var id: OfferId
    public var heading: String
    public var description: String?
    public var images: Set<ImageURL>
    public var webshopURL: URL?
    
    public var runDateRange: Range<Date>
    public var publishDate: Date?
    
    public var price: Price?
    public var quantity: Quantity?
    
    public var branding: Branding_v2?
    
    public var publicationId: PublicationId?
    public var publicationPageIndex: Int?
    public var incitoViewId: String?
    
    public var businessId: BusinessId
    /// The id of the nearest store. Only available if a location was provided when fetching the offer.
    public var storeId: StoreId?
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Offer_v2: Identifiable { }

extension Offer_v2: Decodable {
    
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
        case catalogViewId      = "catalog_view_id"
        case dealerId           = "dealer_id"
        case storeId            = "store_id"
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try values.decode(OfferId.self, forKey: .id)
        self.heading = try values.decode(String.self, forKey: .heading)
        self.description = try? values.decode(String.self, forKey: .description)
        
        self.images = (try? values.decode(v2ImageURLs.self, forKey: .images))?.imageURLSet ?? []
        
        if let links = try? values.decode([String: URL].self, forKey: .links) {
            self.webshopURL = links["webshop"]
        }
        
        let fromDate = (try? values.decode(Date.self, forKey: .runFromDateStr)) ?? Date.distantPast
        let tillDate = (try? values.decode(Date.self, forKey: .runTillDateStr)) ?? Date.distantFuture
        // make sure range is not malformed
        self.runDateRange = min(tillDate, fromDate) ..< max(tillDate, fromDate)
        
        self.publishDate = try? values.decode(Date.self, forKey: .publishDateStr)
        
        self.price = try? values.decode(Price.self, forKey: .price)
        self.quantity = try? values.decode(Quantity.self, forKey: .quantity)
        
        self.branding = try? values.decode(Branding_v2.self, forKey: .branding)
        
        self.publicationId = try? values.decode(PublicationId.self, forKey: .catalogId)
        // incito publications have pageNum == 0, so in that case set to nil.
        // otherwise, convert pageNum to index.
        self.publicationPageIndex = (try? values.decode(Int.self, forKey: .catalogPage)).flatMap({ $0 > 0 ? $0 - 1 : nil })
        self.incitoViewId = try? values.decode(String.self, forKey: .catalogViewId)
        
        self.businessId = try values.decode(BusinessId.self, forKey: .dealerId)
        self.storeId = try? values.decode(StoreId.self, forKey: .storeId)
    }
}

extension Offer_v2 {
    
    public struct Price: Decodable, Equatable {
        public var currency: String
        public var price: Double
        public var prePrice: Double?
        
        public init(currency: String, price: Double, prePrice: Double?) {
            self.currency = currency
            self.price = price
            self.prePrice = prePrice
        }
        
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
            
            public init(from: Double?, to: Double?) {
                self.from = from
                self.to = to
            }
        }
        
        public init(unit: QuantityUnit?, size: QuantityRange, pieces: QuantityRange) {
            self.unit = unit
            self.size = size
            self.pieces = pieces
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
            
            public init(symbol: String, factor: Double) {
                self.symbol = symbol
                self.factor = factor
            }
        }
        
        public init(symbol: String, siUnit: SIUnit) {
            self.symbol = symbol
            self.siUnit = siUnit
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

// MARK: -

public struct Business_v2: Equatable {
    public var id: BusinessId
    public var name: String
    public var website: URL?
    public var description: String?
    public var descriptionMarkdown: String?
    public var logoOnWhite: URL
    public var logoOnBrandColor: URL
    public var brandColorHex: String?
    public var country: String
    public var favoriteCount: Int
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Business_v2: Identifiable { }

extension Business_v2: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case website
        case description
        case descriptionMarkdown = "description_markdown"
        case logoOnWhite = "logo"
        case colorStr = "color"
        case pageFlip = "pageflip"
        case country
        case favoriteCount = "favorite_count"
        
        enum PageFlipKeys: String, CodingKey {
            case logo
            case colorStr = "color"
        }
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try values.decode(BusinessId.self, forKey: .id)
        self.name = try values.decode(String.self, forKey: .name)
        self.website = try? values.decode(URL.self, forKey: .website)
        self.description = try? values.decode(String.self, forKey: .description)
        self.descriptionMarkdown = try? values.decode(String.self, forKey: .descriptionMarkdown)
        self.logoOnWhite = try values.decode(URL.self, forKey: .logoOnWhite)
        self.brandColorHex = try? values.decode(String.self, forKey: .colorStr)
        
        let pageflipValues = try values.nestedContainer(keyedBy: CodingKeys.PageFlipKeys.self, forKey: .pageFlip)
        self.logoOnBrandColor = try pageflipValues.decode(URL.self, forKey: .logo)

        self.country = (try values.decode(Country_v2.self, forKey: .country)).id
        self.favoriteCount = try values.decode(Int.self, forKey: .favoriteCount)
    }
}

#if canImport(UIKit)
import UIKit
extension Business_v2 {
    public var brandColor: UIColor? {
        brandColorHex.flatMap(UIColor.init(hex:))
    }
}
#endif

// MARK: -

public struct Store_v2: Equatable {
    public var id: StoreId
    
    public var street: String?
    public var city: String?
    public var zipCode: String?
    public var country: String
    public var coordinate: Coordinate
    
    public var businessId: BusinessId
    public var branding: Branding_v2
    public var contact: String?
    
    public init(id: StoreId, street: String?, city: String?, zipCode: String?, country: String, coordinate: Coordinate, businessId: BusinessId, branding: Branding_v2, contact: String?) {
        self.id = id
        self.street = street
        self.city = city
        self.zipCode = zipCode
        self.country = country
        self.coordinate = coordinate
        self.businessId = businessId
        self.branding = branding
        self.contact = contact
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Store_v2: Identifiable { }

extension Store_v2: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case street
        case city
        case zipCode    = "zip_code"
        case country
        case latitude
        case longitude
        case dealerId   = "dealer_id"
        case branding
        case contact
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(StoreId.self, forKey: .id)
        self.street = try? container.decode(String.self, forKey: .street)
        self.city = try? container.decode(String.self, forKey: .city)
        self.zipCode = try? container.decode(String.self, forKey: .zipCode)
        self.country = (try container.decode(Country_v2.self, forKey: .country)).id
        
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lng = try container.decode(Double.self, forKey: .longitude)
        self.coordinate = Coordinate(latitude: lat, longitude: lng)

        self.businessId = try container.decode(BusinessId.self, forKey: .dealerId)
        self.branding = try container.decode(Branding_v2.self, forKey: .branding)
        self.contact = try? container.decode(String.self, forKey: .contact)
    }
}

/// just needed for decoding purposes
struct Country_v2: Decodable {
    var id: String
}
