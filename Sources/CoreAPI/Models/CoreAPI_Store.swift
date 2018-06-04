//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import CoreLocation

extension CoreAPI {
    
    public struct Store: Decodable, Equatable {
        public typealias Identifier = GenericIdentifier<Store>
        
        public var id: Identifier
        
        public var street: String?
        public var city: String?
        public var zipCode: String?
        public var country: CoreAPI.Country
        public var coordinate: CLLocationCoordinate2D
        
        public var dealerId: CoreAPI.Dealer.Identifier
        public var branding: CoreAPI.Branding
        public var contact: String?
        
        // MARK: Decodable
        
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
            
            self.id = try container.decode(Identifier.self, forKey: .id)
            self.street = try? container.decode(String.self, forKey: .street)
            self.city = try? container.decode(String.self, forKey: .city)
            self.zipCode = try? container.decode(String.self, forKey: .zipCode)
            self.country = try container.decode(Country.self, forKey: .country)
            
            let lat = try container.decode(CLLocationDegrees.self, forKey: .latitude)
            let lng = try container.decode(CLLocationDegrees.self, forKey: .longitude)
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)

            self.dealerId = try container.decode(CoreAPI.Dealer.Identifier.self, forKey: .dealerId)
            self.branding = try container.decode(CoreAPI.Branding.self, forKey: .branding)
            self.contact = try? container.decode(String.self, forKey: .contact)
        }
    }
}
