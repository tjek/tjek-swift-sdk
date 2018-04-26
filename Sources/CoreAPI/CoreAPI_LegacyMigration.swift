//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension CoreAPI.AuthVault {
    
    struct LegacySession: Decodable {
        var token: String
        var user: CoreAPI.Person?
        var provider: CoreAPI.AuthorizedUserProvider?
        
        var authorizedUser: CoreAPI.AuthorizedUser? {
            guard let person = self.user, let provider = self.provider else {
                return nil
            }
            
            return (person: person, provider: provider)
        }
    }
    
    static func loadLegacyAuthState() -> CoreAPI.AuthVault.AuthState? {
        let clientId = CoreAPI.ClientIdentifier(rawValue: UserDefaults.standard.string(forKey: "ETA_ClientID"))
        
        guard let sessionStr = UserDefaults.standard.object(forKey: "ETA_Session") as? String,
            let sessionData = sessionStr.data(using: .utf8),
            let session = try? JSONDecoder().decode(LegacySession.self, from: sessionData) else {
                
                if clientId != nil {
                    return .unauthorized(error: nil, clientId:
                        clientId)
                } else {
                    return nil
                }
        }
        
        return .authorized(token: session.token,
                           user: session.authorizedUser,
                           clientId: clientId)
    }
    
    static func clearLegacyAuthState() {
        UserDefaults.standard.removeObject(forKey: "ETA_ClientID")
        UserDefaults.standard.removeObject(forKey: "ETA_Session")
    }
}
