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
    var color: UIColor? {
        colorHex.flatMap(UIColor.init(hex:))
    }
}
#endif
