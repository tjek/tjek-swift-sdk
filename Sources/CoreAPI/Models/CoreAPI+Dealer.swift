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
    
    public struct Dealer: Decodable {
        public typealias Identifier = GenericIdentifier<Dealer>
        
        public enum SocialMediaIdentity {
            case facebook(pageId: String)
            case youtube(userId: String)
            case twitter(handle: String)
        }
        
        public var id: Identifier
        public var name: String
        public var website: URL?
        public var description: String?
        public var descriptionMarkdown: String?
        public var logoURL: URL
        public var color: UIColor?
        public var country: Country
        public var favoriteCount: Int
        public var socialMediaIds: [SocialMediaIdentity]
        
        // TODO: missing fields: PageFlip color&logo / category_ids /
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case website
            case description
            case descriptionMarkdown = "description_markdown"
            case logoURL = "logo"
            case colorStr = "color"
            case country
            case favoriteCount = "favorite_count"
            case facebookPageId = "facebook_page_id"
            case youtubeUserId = "youtube_user_id"
            case twitterHandle = "twitter_handle"
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try values.decode(Identifier.self, forKey: .id)
            self.name = try values.decode(String.self, forKey: .name)
            self.website = try? values.decode(URL.self, forKey: .website)
            self.description = try? values.decode(String.self, forKey: .description)
            self.descriptionMarkdown = try? values.decode(String.self, forKey: .descriptionMarkdown)
            self.logoURL = try values.decode(URL.self, forKey: .logoURL)
            if let colorStr = try? values.decode(String.self, forKey: .colorStr) {
                self.color = UIColor(hex: colorStr)
            }
            self.country = try values.decode(Country.self, forKey: .country)
            self.favoriteCount = try values.decode(Int.self, forKey: .favoriteCount)
            
            self.socialMediaIds = [CodingKeys.facebookPageId, .youtubeUserId, .twitterHandle].flatMap({
                guard let socialId = try? values.decode(String.self, forKey: $0) else { return nil }
                switch $0 {
                case .facebookPageId: return .facebook(pageId: socialId)
                case .youtubeUserId: return .youtube(userId: socialId)
                case .twitterHandle: return .twitter(handle: socialId)
                default: return nil
                }
            })
        }
    }
    
    // MARK: -
    
    public struct Country: Decodable {
        typealias Identifier = GenericIdentifier<Country>
        var id: Identifier
    }
}

//{
//    "id": "25f5mL",
//    "ern": "ern:dealer:25f5mL",
//    "name": "3",
//    "website": "http://3.dk",
//    "description": "3 tilbyder danskerne mobiltelefoni og mobilt bredbånd. Kombinationen af 3’s 3G-netværk og lynhurtige 4G /LTE-netværk, sikrer danskerne adgang til fremtidens netværk - i dag.",
//    "description_markdown": null,
//    "logo": "https://d3ikkoqs9ddhdl.cloudfront.net/img/logo/default/25f5mL_2gvnjz51j.png",
//    "color": "000000",
//    "pageflip": {
//        "logo": "https://d3ikkoqs9ddhdl.cloudfront.net/img/logo/pageflip/25f5mL_4ronjz51j.png",
//        "color": "000000"
//    },
//    "category_ids": [],
//    "country": {
//        "id": "DK",
//        "unsubscribe_print_url": null
//    },
//    "favorite_count": 0,
//    "facebook_page_id": "168499089859599",
//    "youtube_user_id": "3Denmark",
//    "twitter_handle": "3BusinessDK"
//}
