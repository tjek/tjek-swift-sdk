//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation
import Valet

public struct Utils {

    static func fetchConfigValue(for key: String) -> AnyObject? {
        if let path = Bundle.main.path(forResource: "ShopGunSDK-Info", ofType: "plist"),
            let configDict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            return configDict[key]
        }
        return nil
    }
    
    public static let ISO8601_dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter
    }()
    public static let ISO8601_ms_dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return formatter
    }()
    
    fileprivate static let keychainValet: VALValet? = VALValet(identifier: "com.shopgun.ios.sdk.keychain", accessibility: .afterFirstUnlock)
    static func setKeychainString(_ string: String, key: String) -> Bool {
        return keychainValet?.setString(string, forKey: key) ?? false
    }
    static func getKeychainString(_ key: String) -> String? {
        return keychainValet?.string(forKey: key)
    }
    static func removeKeychainObject(_ key: String) -> Bool {
        return keychainValet?.removeObject(forKey: key) ?? false
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.

    public subscript (sgn_safe index: Index) -> Iterator.Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}
