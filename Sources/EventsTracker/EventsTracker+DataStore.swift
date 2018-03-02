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
    
    internal static func updateDataStore(_ dataStore: ShopGunSDKSecureDataStore?, clientId: ClientIdentifier?) {
        dataStore?.set(value: clientId?.rawValue, for: clientIdDataStoreKey)
    }
    
    internal static func loadClientId(from dataStore: ShopGunSDKSecureDataStore?) -> ClientIdentifier? {
        guard let rawClientId = dataStore?.get(for: clientIdDataStoreKey) else { return nil }
        
        return ClientIdentifier(rawValue: rawClientId)
    }
}

// MARK: - Legacy ClientId Migration

import Valet

extension EventsTracker {
    
    internal static func loadLegacyClientId() -> ClientIdentifier? {
        let legacyKeychain = VALValet(identifier: "com.shopgun.ios.sdk.keychain", accessibility: .afterFirstUnlock)
        
        guard let clientId = legacyKeychain?.string(forKey: "ClientId"), clientId.count > 0 else {
            return nil
        }
        
        return ClientIdentifier(rawValue: clientId)
    }
    
    internal static func clearLegacyClientId() {
        let legacyKeychain = VALValet(identifier: "com.shopgun.ios.sdk.keychain", accessibility: .afterFirstUnlock)
        legacyKeychain?.removeObject(forKey: "ClientId")
    }
}
