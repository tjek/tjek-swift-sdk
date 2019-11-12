//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation
import Incito
import UIKit

public struct IncitoOffer {
    public struct Product: Decodable {
        public var title: String
    }
    
    public struct Id: Decodable {
        public var type: String
        public var provider: String
        public var value: String
    }
    
    public struct Label {
        public var source: URL
        public var title: String?
        public var link: URL?
    }
    
    public var title: String
    
    public var description: String? = nil
    public var link: URL? = nil
    public var products: [Product] = []
    public var ids: [Id] = []
    public var labels: [Label] = []
    public var featureLabels: [String] = []
}

extension IncitoOffer: Decodable {
    enum CodingKeys: String, CodingKey {
        case title, description, link, products, ids, labels, featureLabels = "feature_labels"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.title = try c.decode(String.self, forKey: .title)
        
        self.description = try? c.decode(String.self, forKey: .description)
        self.link = try? c.decode(URL.self, forKey: .link)
        self.products = (try? c.decode([Product].self, forKey: .products)) ?? []
        self.ids = (try? c.decode([Id].self, forKey: .ids)) ?? []
        self.labels = (try? c.decode([Label].self, forKey: .labels)) ?? []
        self.featureLabels = (try? c.decode([String].self, forKey: .featureLabels)) ?? []
    }
}

extension IncitoOffer.Label: Decodable {
    enum CodingKeys: String, CodingKey {
        case source = "src", title, link
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.source = try c.decode(URL.self, forKey: .source)
        
        self.title = try? c.decode(String.self, forKey: .title)
        self.link = try? c.decode(URL.self, forKey: .link)
    }
}

extension IncitoOffer {
    public init?(element: IncitoDocument.Element) {
        
        guard
            element.isOffer,
            let jsonValue = element.meta[IncitoDocument.Element.offerMetaKey],
            let jsonData: Data = try? JSONEncoder().encode(jsonValue),
            var offer = try? JSONDecoder().decode(IncitoOffer.self, from: jsonData)
            else {
            return nil
        }
        
        // feature labels are not part of the meta, so add them separately
        offer.featureLabels = element.featureLabels
        
        self = offer
    }
}

extension IncitoOffer {
    /// Return the `id` for provider 'tjek' or 'shopgun'
    public var coreId: String? {
        return self.ids.firstId(forProvider: "tjek")
            ?? self.ids.firstId(forProvider: "shopgun")
    }
}

extension Array where Element == IncitoOffer.Id {
    /// Note: `provider` is case-insensitively compared.
    public func firstId(forProvider provider: String) -> String? {
        return self.first(where: {
            $0.type.lowercased() == "id" && $0.provider.lowercased() == provider.lowercased() }
            )?.value
    }
}

extension IncitoDocument.Element {
    
    public static let offerMetaKey = "tjek.offer.v1"
    
    public var isOffer: Bool {
        return self.role == "offer"
    }
    
    /// If this element is an offer, try to decode the IncitoOffer from the `meta`.
    public var offer: IncitoOffer? {
        return IncitoOffer(element: self)
    }
}

extension IncitoViewController {
    
    public func firstOffer(at point: CGPoint, completion: @escaping ((IncitoDocument.Element.Identifier, IncitoOffer)?) -> Void) {
        
        self.getFirstElement(at: point, where: { $0.isOffer }) { element in
            guard let id = element?.id, let offer = element?.offer else {
                completion(nil)
                return
            }
            completion((id, offer))
        }
    }
}
