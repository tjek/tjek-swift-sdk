//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension CoreAPI {
    
    public struct Person: Equatable, Codable {
        public typealias Identifier = GenericIdentifier<Person>
        
        public enum Gender: String, Codable {
            case male
            case female
        }

        public var id: Identifier
        public var name: String
        public var email: String
        public var gender: Gender?
        public var birthYear: Int?
        
        // MARK: - Codable
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case email
            case gender
            case birthYear = "birth_year"
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            // In the infinite wisdom of the CoreAPI, id is sent from the endpoint (for now) as an Int
            // it is encoded to disk as a string (and could/should be a string in the future), so also decode from String
            if let intId = try? values.decode(Int.self, forKey: .id) {
                self.id = Identifier(rawValue: String(intId))
            } else {
                self.id = try values.decode(Identifier.self, forKey: .id)
            }
            
            self.name = try values.decode(String.self, forKey: .name)
            self.email = try values.decode(String.self, forKey: .email)
            self.gender = try? values.decode(Gender.self, forKey: .gender)
            self.birthYear = try? values.decode(Int.self, forKey: .birthYear)
        }
        
        // MARK: - Equatable
        
        public static func == (lhs: CoreAPI.Person, rhs: CoreAPI.Person) -> Bool {
            return lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.email == rhs.email
                && lhs.gender == rhs.gender
                && lhs.birthYear == rhs.birthYear
        }
    }
}
