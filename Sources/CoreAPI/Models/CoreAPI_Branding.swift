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
    
    public struct Branding: Decodable, Equatable {
        
        public var name: String?
        public var website: URL?
        public var description: String?
        public var logoURL: URL?
        public var color: UIColor?

        // MARK: Equatable
        
        public static func == (lhs: CoreAPI.Branding, rhs: CoreAPI.Branding) -> Bool {
            return lhs.name == rhs.name
                && lhs.description == rhs.description
                && lhs.website == rhs.website
                && lhs.logoURL == rhs.logoURL
                && lhs.color == rhs.color
        }
        
        // MARK: Decodable
        
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
