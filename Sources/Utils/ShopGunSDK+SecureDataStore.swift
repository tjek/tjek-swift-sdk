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

extension ShopGunSDK {
    static var isRunningInPlayground: Bool {
        return Bundle.main.bundleIdentifier?.hasPrefix("com.apple.dt.playground.") ?? false
    }
}

protocol ShopGunSDKSecureDataStore: class {
    func set(value: String?, for key: String)
    func get(for key: String) -> String?
}

extension ShopGunSDK {
    
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
        private let valet: VALValet?

        // TODO: will fail if not in entitlements
        init(sharedKeychainGroupId: String?) {
            if let sharedGroupId = sharedKeychainGroupId {
                self.valet = VALValet(sharedAccessGroupIdentifier: sharedGroupId,
                                      accessibility: .afterFirstUnlock)
            } else {
                self.valet = VALValet(identifier: "com.shopgun.ios.sdk.keychain-store",
                                      accessibility: .afterFirstUnlock)
            }
        }
        
        func set(value: String?, for key: String) {
            if let val = value {
                valet?.setString(val, forKey: key)
            } else {
                valet?.removeObject(forKey: key)
            }
        }
        func get(for key: String) -> String? {
            return valet?.string(forKey: key)
        }
    }
}
