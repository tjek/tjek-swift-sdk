import Foundation
import Valet

public protocol ShopGunSDKDataStore: class {
    func set(value: String?, for key: String)
    func get(for key: String) -> String?
}

final public class KeychainDataStore {
    
    public let settings: Settings.KeychainDataStore
    
    fileprivate let valet: Valet?

    internal init(settings: Settings.KeychainDataStore) {
        self.settings = settings
        
        var valet: Valet? = nil
        
        if case .sharedKeychain(let groupId) = settings,
            let keychainId = Identifier(nonEmpty: groupId) {
        
            valet = Valet.sharedAccessGroupValet(with: keychainId, accessibility: .afterFirstUnlock)
            if valet?.canAccessKeychain() == false {
                valet = nil
                Logger.log("Unable to access shared keychain group '\(keychainId)'. Will attempt to save secure data in an unshared keychain instead.", level: .important, source: .ShopGunSDK)
            }
        }
        
        // if the valet is unable to access the keychain, revert to a non-shared store
        if valet == nil {
            valet = Valet.valet(with: Identifier(nonEmpty: "com.shopgun.ios.sdk.keychain-store")!, accessibility: .afterFirstUnlock)
            
            if valet?.canAccessKeychain() == false {
                Logger.log("Unable to access keychain. Secure data will not be cached.", level: .error, source: .ShopGunSDK)
            }
        }
        self.valet = valet
    }
    
    private init() { fatalError("You must provide settings when creating a KeychainDataStore") }
}

// MARK: -

extension KeychainDataStore: ShopGunSDKDataStore {

    public func set(value: String?, for key: String) {
        if let val = value {
            valet?.set(string: val, forKey: key)
        } else {
            valet?.removeObject(forKey: key)
        }
    }
    
    public func get(for key: String) -> String? {
        return valet?.string(forKey: key)
    }
}

// MARK: -

extension KeychainDataStore {
    fileprivate static var _shared: KeychainDataStore?

    // TODO test thread safety. What if access shared while calling `configure`
    public static var shared: KeychainDataStore {
        if _shared == nil {
            // first time non-configured dataStore is requested it is configured based on the shared config file (if available).
            configure((try? Settings.loadShared())?.keychainDataStore ?? .privateKeychain)
        }
        return _shared!
    }

    public static var isConfigured: Bool {
        return _shared != nil
    }
    
    public static func configure(_ settings: Settings.KeychainDataStore) {
        guard isConfigured == false else {
            Logger.log("Cannot re-configure KeychainDataStore", level: .error, source: .ShopGunSDK)
            return
        }

        Logger.log("Configuring KeychainDataStore", level: .verbose, source: .ShopGunSDK)
        _shared = KeychainDataStore(settings: settings)
    }
}
