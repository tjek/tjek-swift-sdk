//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension EventsTracker {
    
    fileprivate static let clientIdDataStoreKey = "ShopGunSDK.EventsTracker.ClientId"
    
    internal static func updateDataStore(_ dataStore: ShopGunSDKDataStore?, clientId: ClientIdentifier?) {
        dataStore?.set(value: clientId?.rawValue, for: clientIdDataStoreKey)
    }
    
    internal static func loadClientId(from dataStore: ShopGunSDKDataStore?) -> ClientIdentifier? {
        guard let rawClientId = dataStore?.get(for: clientIdDataStoreKey) else { return nil }
        
        return ClientIdentifier(rawValue: rawClientId)
    }
}

// MARK: - Legacy ClientId Migration

import Valet

extension EventsTracker {
    
    private static var legacyKeychain: Valet {
        return Valet.valet(with: Identifier(nonEmpty: "com.shopgun.ios.sdk.keychain")!, accessibility: .afterFirstUnlock)
    }
    
    internal static func loadLegacyClientId() -> ClientIdentifier? {
        guard let clientId = self.legacyKeychain.string(forKey: "ClientId"), clientId.count > 0 else {
            return nil
        }
        
        return ClientIdentifier(rawValue: clientId)
    }
    
    internal static func clearLegacyClientId() {
        self.legacyKeychain.removeObject(forKey: "ClientId")
    }
}
