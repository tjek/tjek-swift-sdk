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

struct Utils {

    static func fetchInfoPlistValue(key:String) -> AnyObject? {
        
        if let configDict = NSBundle.mainBundle().objectForInfoDictionaryKey("ShopGunSDK")?.copy() {
            
            return configDict[key]
        }
        return nil
    }
    
    static let ISO8601_dateFormatter:NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter
    }()
    
    
    private static let keychainValet:VALValet? = VALValet(identifier: "com.shopgun.ios.sdk.keychain", accessibility: .AfterFirstUnlock)
    static func setKeychainString(string:String, key:String) -> Bool {
        return keychainValet?.setString(string, forKey: key) ?? false
    }
    static func getKeychainString(key:String) -> String? {
        return keychainValet?.stringForKey(key)
    }
    static func removeKeychainObject(key:String) -> Bool {
        return keychainValet?.removeObjectForKey(key) ?? false
    }
}




extension CollectionType {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Generator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

