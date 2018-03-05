//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import Valet

extension ShopGun {
    static var isRunningInPlayground: Bool {
        return Bundle.main.bundleIdentifier?.hasPrefix("com.apple.dt.playground.") ?? false
    }
}

protocol ShopGunSDKSecureDataStore: class {
    func set(value: String?, for key: String)
    func get(for key: String) -> String?
}

extension ShopGun {
    
    class PlaygroundDataStore: ShopGunSDKSecureDataStore {
        func set(value: String?, for key: String) {
            UserDefaults.standard.set(value, forKey: key)
        }
        func get(for key: String) -> String? {
            let value = UserDefaults.standard.string(forKey: key)
            return value
        }
    }
    
    class KeychainDataStore: ShopGunSDKSecureDataStore {
        private let valet: Valet?

        init(sharedKeychainGroupId: String?) {
            
            var valet: Valet? = nil
            
            if let sharedGroupId = Identifier(nonEmpty: sharedKeychainGroupId) {
                valet = Valet.sharedAccessGroupValet(with: sharedGroupId, accessibility: .afterFirstUnlock)
                if valet?.canAccessKeychain() == false {
                    valet = nil
                    ShopGun.log("Unable to access shared keychain group '\(sharedGroupId)'. Will attempt to save secure data in an unshared keychain instead.", level: .important, source: .ShopGunSDK)
                }
            }
            
            // if the valet is unable to access the keychain, revert to a non-shared store
            if valet == nil {
                valet = Valet.valet(with: Identifier(nonEmpty: "com.shopgun.ios.sdk.keychain-store")!, accessibility: .afterFirstUnlock)
                
                if valet?.canAccessKeychain() == false {
                    ShopGun.log("Unable to access keychain. Secure data will not be cached.", level: .error, source: .ShopGunSDK)
                }
            }
            self.valet = valet
        }
        
        func set(value: String?, for key: String) {
            if let val = value {
                valet?.set(string: val, forKey: key)
            } else {
                valet?.removeObject(forKey: key)
            }
        }
        func get(for key: String) -> String? {
            return valet?.string(forKey: key)
        }
    }
}
