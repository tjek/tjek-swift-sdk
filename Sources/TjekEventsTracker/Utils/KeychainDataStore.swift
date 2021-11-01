import Foundation
import Valet

public final class KeychainDataStore {
    
    public enum Config: Equatable {
        /// A `nil` value for the private id will use the default sdk keychain store.
        case privateKeychain(id: String? = nil)
        case sharedKeychain(groupId: String)
    }

    public let config: Config
    
    fileprivate let valet: Valet?

    public init(config: Config) {
        self.config = config
        
        self.valet = {
            // Valet totally fails when running in an Xcode Playground.
            if Bundle.main.isXcodePlayground {
//                Logger.log("KeychainDataStore is not available in Xcode Playgrounds.", level: .important, source: .ShopGunSDK)
                return nil
            }
            
            // Based on the Valet documentation, on iOS this MUST be "group".
            if case .sharedKeychain(let groupId) = config,
               let keychainId = SharedGroupIdentifier(groupPrefix: "group", nonEmptyGroup: groupId) {
                
                let valet = Valet.sharedGroupValet(with: keychainId, accessibility: .afterFirstUnlock)
                if valet.canAccessKeychain() {
                    return valet
                } else {
//                    Logger.log("Unable to access shared keychain group. Secure data will not be cached.", level: .important, source: .ShopGunSDK)
                    return nil
                }
            } else if case .privateKeychain(let privateId) = config,
                let keychainId = Identifier(nonEmpty: privateId ?? "com.shopgun.ios.sdk.keychain-store") {
                
                let valet = Valet.valet(with: keychainId, accessibility: .afterFirstUnlock)
                
                if valet.canAccessKeychain() {
                    return valet
                } else {
//                    Logger.log("Unable to access keychain. Secure data will not be cached.", level: .error, source: .ShopGunSDK)
                    return nil
                }
            } else {
                return nil
            }
            
        }()
    }
    
    private init() { fatalError("You must provide settings when creating a KeychainDataStore") }
}

// MARK: -

extension KeychainDataStore {

    func set(value: String?, for key: String) {
        if let val = value {
            try? valet?.setString(val, forKey: key)
        } else {
            try? valet?.removeObject(forKey: key)
        }
    }
    
    func get(for key: String) -> String? {
        return try? valet?.string(forKey: key)
    }
}

// MARK: -

//extension KeychainDataStore {
//    fileprivate static var _shared: KeychainDataStore?
//
//    // TODO test thread safety. What if access shared while calling `configure`
//    public static var shared: KeychainDataStore {
//        if _shared == nil {
//            // first time non-configured dataStore is requested it is configured based on the shared config file (if available).
//            configure((try? Settings.loadShared())?.keychainDataStore ?? .privateKeychain(id: nil))
//        }
//        return _shared!
//    }
//
//    public static var isConfigured: Bool {
//        return _shared != nil
//    }
//
//    /**
//     Configure the `shared` KeychainDataStore instance. Will be a no-op if the shared KeychainDataStore has already been configured.
//     - parameter settings: The settings to configure the shared datastore with.
//     **/
//    public static func configure(_ settings: Settings.KeychainDataStore) {
//        guard isConfigured == false else {
//            Logger.log("Cannot re-configure KeychainDataStore", level: .error, source: .ShopGunSDK)
//            return
//        }
//
//        Logger.log("Configuring KeychainDataStore", level: .verbose, source: .ShopGunSDK)
//        _shared = KeychainDataStore(settings: settings)
//    }
//}

extension Bundle {
    fileprivate var isXcodePlayground: Bool {
        return self.bundleIdentifier?.hasPrefix("com.apple.dt.playground.") ?? false
    }
}
