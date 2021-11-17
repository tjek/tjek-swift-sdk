///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

public struct Business_v4: Equatable, Hashable {
    
    public typealias ID = BusinessId
    
    public var id: ID
    public var name: String
    public var countryCode: String
    public var primaryColorHex: String
    public var logotypesForWhite: Set<ImageURL>
    public var logotypesForPrimary: Set<ImageURL>
    public var shortDescription: String?
    public var website: URL?
    
    public init(
        id: ID,
        name: String,
        countryCode: String,
        primaryColorHex: String,
        logotypesForWhite: Set<ImageURL>,
        logotypesForPrimary: Set<ImageURL>,
        shortDescription: String?,
        website: URL?
    ) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.primaryColorHex = primaryColorHex
        self.logotypesForWhite = logotypesForWhite
        self.logotypesForPrimary = logotypesForPrimary
        self.shortDescription = shortDescription
        self.website = website
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Business_v4: Identifiable { }

extension Business_v4: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case countryCode            = "country_code"
        case primaryColorHex        = "primary_color"
        case logotypesForWhite      = "positive_logotypes"
        case logotypesForPrimary    = "negative_logotypes"
        case shortDescription       = "short_description"
        case website                = "website_link"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try c.decode(Business_v4.ID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.countryCode = (try c.decode(String.self, forKey: .countryCode)).uppercased()
        self.primaryColorHex = try c.decode(String.self, forKey: .primaryColorHex)
        self.logotypesForWhite = try c.decode(Set<ImageURL>.self, forKey: .logotypesForWhite)
        self.logotypesForPrimary = try c.decode(Set<ImageURL>.self, forKey: .logotypesForPrimary)
        self.shortDescription = (try? c.decode(String.self, forKey: .shortDescription)).flatMap({ $0.isEmpty ? nil : $0 })
        self.website = try? c.decode(URL.self, forKey: .shortDescription)
    }
}

extension Business_v4 {
    public init(v2: Business_v2) {
        self.id = v2.id
        self.name = v2.name
        self.countryCode = v2.country
        self.primaryColorHex = v2.brandColorHex ?? "#FFFFFF"
        self.logotypesForWhite = [ImageURL(url: v2.logoOnWhite, width: 160)]
        self.logotypesForPrimary = [ImageURL(url: v2.logoOnBrandColor, width: 160)]
        self.shortDescription = v2.description
        self.website = v2.website
    }
}

#if canImport(UIKit)
import UIKit

extension Business_v4 {
    public var primaryColor: UIColor {
        UIColor(hex: self.primaryColorHex) ?? .white
    }
}
#endif

// MARK: -

public struct Offer_v4: Equatable, Hashable {
    
    public typealias ID = OfferId
    
    public var id: ID
    
    public var name: String
    public var description: String?
    public var images: Set<ImageURL>
    public var webshopLink: URL?
    
    public var price: Double
    public var currencyCode: String
    public var savings: Double?
    
    public var pieceCountRange: ClosedRange<Double>
    public var unitSymbol: QuantityUnit
    public var unitSizeRange: ClosedRange<Double>
    
    public var validFrom: Date?
    public var validUntil: Date?
    public var visibleFrom: Date
    
    public var business: Business_v4
    public var publicationId: PublicationId?
    public var publicationPageIndex: Int?
    public var incitoViewId: String?
    
    public init(
        id: ID,
        name: String,
        description: String? = nil,
        images: Set<ImageURL>,
        webshopLink: URL? = nil,
        price: Double,
        currencyCode: String,
        savings: Double? = nil,
        pieceCountRange: ClosedRange<Double>,
        unitSymbol: QuantityUnit,
        unitSizeRange: ClosedRange<Double>,
        validFrom: Date?,
        validUntil: Date?,
        visibleFrom: Date,
        business: Business_v4,
        publicationId: PublicationId? = nil,
        publicationPageIndex: Int? = nil,
        incitoViewId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.images = images
        self.webshopLink = webshopLink
        self.price = price
        self.currencyCode = currencyCode
        self.savings = savings
        self.pieceCountRange = pieceCountRange
        self.unitSymbol = unitSymbol
        self.unitSizeRange = unitSizeRange
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.visibleFrom = visibleFrom
        self.business = business
        self.publicationId = publicationId
        self.publicationPageIndex = publicationPageIndex
        self.incitoViewId = incitoViewId
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Offer_v4: Identifiable { }

extension Offer_v4 {
    
    public var validityRange: Range<Date> {
        let from = validFrom ?? .distantPast
        let until = validUntil ?? .distantFuture
        return min(from, until) ..< max(from, until)
    }
    
    public func isExpired(relativeTo currentDate: Date = Date()) -> Bool {
        (validUntil ?? .distantFuture) < currentDate
    }
}

extension Offer_v4 {
    public init(v2 v2Model: Offer_v2, business: Business_v4) {
        self.id = v2Model.id
        self.name = v2Model.heading
        self.description = v2Model.description
        self.images = v2Model.images
        self.webshopLink = v2Model.webshopURL
        
        let price = v2Model.price?.price ?? 0
        self.price = price
        self.currencyCode = v2Model.price?.currency ?? "DKK"
        self.savings = v2Model.price?.prePrice.map({ $0 - price })
        
        let piecesRange = (from: v2Model.quantity?.pieces.from ?? 1, to: v2Model.quantity?.pieces.to ?? 1)
        self.pieceCountRange = min(piecesRange.from, piecesRange.to)...max(piecesRange.from, piecesRange.to)
        let unitSizeRange = (from: v2Model.quantity?.size.from ?? 0, to: v2Model.quantity?.size.to ?? 0)
        self.unitSymbol = (v2Model.quantity?.unit?.symbol).flatMap(QuantityUnit.init(symbol:)) ?? .piece
        self.unitSizeRange = min(unitSizeRange.from, unitSizeRange.to)...max(unitSizeRange.from, unitSizeRange.to)
        self.validFrom = v2Model.runDateRange.lowerBound == .distantPast ? nil : v2Model.runDateRange.lowerBound
        self.validUntil = v2Model.runDateRange.upperBound == .distantFuture ? nil : v2Model.runDateRange.upperBound
        self.visibleFrom = v2Model.publishDate ?? .distantPast
        self.business = business
        self.publicationId = v2Model.publicationId
        self.publicationPageIndex = v2Model.publicationPageIndex
        self.incitoViewId = v2Model.incitoViewId
    }
}

// MARK: - Codable

fileprivate struct APIRange<T> {
    var from: T
    var to: T
    
    func map<NewT>(_ transform: (T) throws -> NewT) rethrows -> APIRange<NewT> {
        APIRange<NewT>(from: try transform(from), to: try transform(to))
    }
}
extension APIRange: Decodable where T: Decodable { }
extension APIRange: Encodable where T: Encodable { }

extension APIRange where T: Comparable {
    init(_ range: ClosedRange<T>) {
        self.from = range.lowerBound
        self.to = range.upperBound
    }
    init(_ range: Range<T>) {
        self.from = range.lowerBound
        self.to = range.upperBound
    }
    
    var closedRange: ClosedRange<T> {
        min(from, to)...max(from, to)
    }
    
    var range: Range<T> {
        min(from, to)..<max(from, to)
    }
}

extension Offer_v4: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case images
        case webshopLink        = "webshop_link"
        case price
        case currencyCode       = "currency_code"
        case savings
        case pieceCount         = "piece_count"
        case unitSymbol         = "unit_symbol"
        case unitSize           = "unit_size"
        case validity
        case visibleFrom        = "visible_from"
        case business
        case publicationId      = "publication_id"
        case publicationPageIndex = "publication_page_index"
        case incitoViewId       = "catalog_view_id"
        case oldPubLocation     = "publication"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try c.decode(ID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.description = try? c.decode(String.self, forKey: .description)
        self.images = try c.decode(Set<ImageURL>.self, forKey: .images)
        self.webshopLink = try? c.decode(URL.self, forKey: .webshopLink)
        self.price = try c.decode(Double.self, forKey: .price)
        self.currencyCode = try c.decode(String.self, forKey: .currencyCode)
        self.savings = try? c.decode(Double.self, forKey: .savings)
        self.pieceCountRange = (try c.decode(APIRange<Double>.self, forKey: .pieceCount)).closedRange
        self.unitSymbol = try c.decode(QuantityUnit.self, forKey: .unitSymbol)
        self.unitSizeRange = (try c.decode(APIRange<Double>.self, forKey: .unitSize)).closedRange
        
        let validityRange: APIRange<Date?> = try c.decode(APIRange<Date?>.self, forKey: .validity)
        self.validFrom = validityRange.from
        self.validUntil = validityRange.to
        self.visibleFrom = try c.decode(Date.self, forKey: .visibleFrom)
        self.business = try c.decode(Business_v4.self, forKey: .business)
        
        // due to some rather foolish data-modelling, we need to pull old format into a 'flatted' version of the same data.
        lazy var oldPublicationLocation = try? c.decode(OldPublicationLocation.self, forKey: .oldPubLocation)
        self.publicationId = (try? c.decode(PublicationId.self, forKey: .publicationId)) ?? oldPublicationLocation?.id
        self.publicationPageIndex = (try? c.decode(Int.self, forKey: .publicationPageIndex)) ?? oldPublicationLocation?.pageIndex
        self.incitoViewId = try? c.decode(String.self, forKey: .incitoViewId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        
        try c.encode(self.id, forKey: .id)
        try c.encode(self.name, forKey: .name)
        try c.encode(self.description, forKey: .description)
        try c.encode(self.images, forKey: .images)
        try c.encode(self.webshopLink, forKey: .webshopLink)
        try c.encode(self.price, forKey: .price)
        try c.encode(self.currencyCode, forKey: .currencyCode)
        try c.encode(self.savings, forKey: .savings)
        try c.encode(APIRange(self.pieceCountRange), forKey: .pieceCount)
        try c.encode(self.unitSymbol, forKey: .unitSymbol)
        try c.encode(APIRange(self.unitSizeRange), forKey: .unitSize)
        try c.encode(APIRange(from: self.validFrom, to: self.validUntil), forKey: .validity)
        try c.encode(self.visibleFrom, forKey: .visibleFrom)
        try c.encode(self.business, forKey: .business)
        try c.encode(self.publicationId, forKey: .publicationId)
        try c.encode(self.publicationPageIndex, forKey: .publicationPageIndex)
        try c.encode(self.incitoViewId, forKey: .incitoViewId)
    }
}

fileprivate enum OldPublicationLocation: Equatable, Hashable, Decodable {
    case incito(id: PublicationId)
    case paged(id: PublicationId, pageIndex: Int)
    
    var id: PublicationId {
        switch self {
        case .incito(let id), .paged(let id, _):
            return id
        }
    }
    var pageIndex: Int? {
        guard case .paged(_, let pageIndex) = self else {
            return nil
        }
        return pageIndex
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case pageIndex
    }
    
    enum PublicationType: String, Codable {
        case incito
        case paged
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(PublicationType.self, forKey: .type)
        let id = try c.decode(PublicationId.self, forKey: .id)
        switch type {
        case .incito:
            self = .incito(id: id)
        case .paged:
            let pageIndex = (try? c.decode(Int.self, forKey: .pageIndex)) ?? 0
            self = .paged(id: id, pageIndex: pageIndex)
        }
    }
}

// MARK: -

public enum QuantityUnit: String, CaseIterable, Equatable, Codable, Hashable {
    
    // mass (base unit: grams)
    case microgram = "microgram" // 0.000001 g
    case milligram = "milligram" // 0.001 g
    case centigram = "centigram" // 0.01 g
    case decigram  = "decigram"  // 0.1 g
    case gram      = "gram"      // 1 g
    case kilogram  = "kilogram"  // 1_000 g
    case tonne     = "tonne"     // 1_000_000 g
    
    case imperialTon = "imperial_ton" // 1016050 g
    case usTon       = "us_ton"       // 907185 g
    case stone       = "stone"        // 6350.29 g
    case pound       = "pound"        // 453.592 g
    case ounce       = "ounce"        // 28.3495 g
    
    // volume (base unit: liters)
    case milliliter = "milliliter"  // 0.001 l
    case centiliter = "centiliter"  // 0.01 l
    case deciliter  = "deciliter"   // 0.1 l
    case liter      = "liter"       // 1 l
    case kiloliter  = "kiloliter"   // 1_000 l
    case cubicMeter = "cubic_meter" // 1_000 l
    case megaliter  = "megaliter"   // 1_000_000 l
    
    case usTeaspoon   = "us_teaspoon"    // 0.00492892 l
    case usTablespoon = "us_tablespoon"  // 0.0147868 l
    case usFluidOunce = "us_fluid_ounce" // 0.0295735 l
    case usCup        = "us_cup"         // 0.24 l
    case usPint       = "us_pint"        // 0.473176 l
    case usQuart      = "us_quart"       // 0.946353 l
    case usGallon     = "us_gallon"      // 3.78541 l
    
    case imperialTeaspoon   = "imperial_teaspoon"    // 0.00591939 l
    case imperialTablespoon = "imperial_tablespoon"  // 0.0177582 l
    case imperialFluidOunce = "imperial_fluid_ounce" // 0.0284131 l
    case imperialPint       = "imperial_pint"        // 0.568261 l
    case imperialQuart      = "imperial_quart"       // 1.13652 l
    case imperialGallon     = "imperial_gallon"      // 4.54609 l
    
    case cubicInch = "cubic_inch" // 0.0163871 l
    case cubicFoot = "cubic_foot" // 28.3168 l
    
    // other
    case piece = "piece"
}

extension QuantityUnit {
    
    public var unit: Unit? {
        switch self {
        case .microgram: return UnitMass.micrograms
        case .milligram: return UnitMass.milligrams
        case .centigram: return UnitMass.centigrams
        case .decigram: return UnitMass.decigrams
        case .gram: return UnitMass.grams
        case .kilogram: return UnitMass.kilograms
        case .tonne: return UnitMass.metricTons
        case .usTon: return UnitMass.shortTons
        case .imperialTon:
            return UnitMass(symbol: "t", converter: UnitConverterLinear(coefficient: 1016.0469))
        case .stone: return UnitMass.stones
        case .pound: return UnitMass.pounds
        case .ounce: return UnitMass.ounces
        case .milliliter: return UnitVolume.milliliters
        case .centiliter: return UnitVolume.centiliters
        case .deciliter: return UnitVolume.deciliters
        case .liter: return UnitVolume.liters
        case .kiloliter: return UnitVolume.kiloliters
        case .cubicMeter: return UnitVolume.cubicMeters
        case .megaliter: return UnitVolume.megaliters
        case .usTeaspoon: return UnitVolume.teaspoons
        case .usTablespoon: return UnitVolume.tablespoons
        case .usFluidOunce: return UnitVolume.fluidOunces
        case .usCup: return UnitVolume.cups
        case .usPint: return UnitVolume.pints
        case .usQuart: return UnitVolume.quarts
        case .usGallon: return UnitVolume.gallons
        case .imperialTeaspoon: return UnitVolume.imperialTeaspoons
        case .imperialTablespoon: return UnitVolume.imperialTablespoons
        case .imperialFluidOunce: return UnitVolume.imperialFluidOunces
        case .imperialPint: return UnitVolume.imperialPints
        case .imperialQuart: return UnitVolume.imperialQuarts
        case .imperialGallon: return UnitVolume.imperialGallons
        case .cubicInch: return UnitVolume.cubicInches
        case .cubicFoot: return UnitVolume.cubicFeet
        case .piece: return nil
        }
    }
    
    /**
     The symbol of the quantity's unit. eg. 'l' for liters.
     For `pieces` the symbol is 'pcs'.
     */
    public var symbol: String {
        return self.unit?.symbol ?? "pcs"
    }
    
    /**
     Try to create a QuantityUnit, based on the 'symbol' value.
     */
    public init?(symbol: String) {
        if let unit = QuantityUnit.allCases.first(where: { $0.symbol.lowercased() == symbol.lowercased() }) {
            self = unit
        } else {
            return nil
        }
    }
    
    /// How much we multiply a quantity of this unit to get it into the `to` unit
    /// For example `QuantityUnit.gram.conversionFactor(to: .kilogram)` = 0.001
    /// Undefined result when converting from different unit types, like volume to mass.
    public func conversionFactor(to: QuantityUnit) -> Double? {
        guard let fromUnit = self.unit as? Dimension, let toUnit = to.unit as? Dimension else { return nil }
        
        return Measurement(value: 1, unit: fromUnit)
            .converted(to: toUnit)
            .value
    }
    
    public var isMetric: Bool {
        switch self {
            
        case .microgram, .milligram, .centigram, .decigram, .gram, .kilogram, .tonne, .milliliter, .centiliter, .deciliter, .liter, .kiloliter, .cubicMeter, .megaliter, .piece:
            return true
            
        default:
            return false
        }
    }
    
    public var isVolume: Bool {
        switch self {
        case .milliliter, .centiliter, .deciliter, .liter, .kiloliter, .cubicMeter, .megaliter, .usTeaspoon, .usTablespoon, .usFluidOunce, .usCup, .usPint, .usQuart, .usGallon, .imperialTeaspoon, .imperialTablespoon, .imperialFluidOunce, .imperialPint, .imperialQuart, .imperialGallon, .cubicInch, .cubicFoot:
            return true
        default:
            return false
        }
    }
    
    public var isMass: Bool {
        switch self {
        case .microgram, .milligram, .centigram, .decigram, .gram, .kilogram, .tonne, .usTon, .imperialTon, .stone, .pound, .ounce:
            return true
        default:
            return false
        }
    }
}
