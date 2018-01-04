//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation

extension CoreAPI {
    /// The dateFormatter of all the dates in/out of the CoreAPI
    static let dateFormatter:DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter
    }()
}

extension CoreAPI {
    
    // MARK: -
    
    public struct Person: Decodable {
        //        var email: String
    }
    
    // MARK: -
    
    internal struct AuthSession: Decodable {
        var clientId: String?
        var token: String
        var expiry: Date
        
        var auth: (person: CoreAPI.Person, provider: AuthProvider)?
        
        enum AuthProvider: String, Decodable {
            case shopgun = "shopgun"
            case facebook = "facebook"
        }
        
        enum CodingKeys: String, CodingKey {
            case clientId   = "client_id"
            case token      = "token"
            case expiry     = "expires"
            case provider   = "provider"
            case person     = "user"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            self.clientId = try? values.decode(String.self, forKey: .clientId)
            self.token = try values.decode(String.self, forKey: .token)
            
            if let provider = try? values.decode(AuthProvider.self, forKey: .provider),
                let person = try? values.decode(Person.self, forKey: .person) {
                self.auth = (person, provider)
            }
            
            let expiryString = try values.decode(String.self, forKey: .expiry)
            if let expiryDate = CoreAPI.dateFormatter.date(from: expiryString) {
                self.expiry = expiryDate
            } else {
                throw DecodingError.dataCorruptedError(forKey: .expiry, in: values, debugDescription: "Date string does not match format expected by formatter.")
            }
        }
    }
    
    // MARK: -
    
    public struct Country: Decodable {
        typealias Identifier = GenericIdentifier<Country>
        var id: String
        var unsubscribePrintURL: URL?
    }
    
    // MARK: -
    
    public struct Dealer: Decodable {
        public typealias Identifier = GenericIdentifier<Dealer>
        
        public var uuid: Identifier
        public var name: String
        public var website: URL?
        public var description: String?
        public var descriptionMarkdown: String?
        public var logo: URL
        public var color: String
        // TODO: PageFlip color/logo
        public var country: Country
        public var favoriteCount: Int
        
        public var facebookPageId: String?
        public var youtubeUserId: String?
        public var twitterHandle: String?
        
        enum CodingKeys: String, CodingKey {
            case uuid   = "id"
            case name
            case website
            case description
            case descriptionMarkdown = "description_markdown"
            case logo
            case color
            case country
            case favoriteCount = "favorite_count"
            case facebookPageId = "facebook_page_id"
            case youtubeUserId = "youtube_user_id"
            case twitterHandle = "twitter_handle"
        }
//        [{"id":"25f5mL","ern":"ern:dealer:25f5mL","name":"3","website":"http:\/\/3.dk","description":"3 tilbyder danskerne mobiltelefoni og mobilt bredb\u00e5nd. Kombinationen af 3\u2019s 3G-netv\u00e6rk og lynhurtige 4G \/LTE-netv\u00e6rk, sikrer danskerne adgang til fremtidens netv\u00e6rk - i dag.","description_markdown":null,"logo":"https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/logo\/default\/25f5mL_2gvnjz51j.png","color":"000000","pageflip":{"logo":"https:\/\/d3ikkoqs9ddhdl.cloudfront.net\/img\/logo\/pageflip\/25f5mL_4ronjz51j.png","color":"000000"},"category_ids":[],"country":{"id":"DK","unsubscribe_print_url":null},"favorite_count":0,"facebook_page_id":"168499089859599","youtube_user_id":"3Denmark","twitter_handle":"3BusinessDK"},
    }
}
