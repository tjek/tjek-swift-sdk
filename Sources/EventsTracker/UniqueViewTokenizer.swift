//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

/// The signature of a Tokenize function, for converting a string to a different string.
typealias Tokenizer = (String) -> String

/// A struct for generating a unique view token, based on a salt and a content string.
/// Given the same salt & content, the same viewToken will be generated.
struct UniqueViewTokenizer {
    let salt: String
    
    /**
     Create a new UniqueViewTokenizer. Will fail if the provided salt is empty.
     */
    init?(salt: String) {
        guard salt.isEmpty == false else {
            return nil
        }
        self.salt = salt
    }
    
    /**
     Takes a content string, combines with the Tokenizer's salt, and hashes into a new string.
     - parameter content: A string that will be tokenized.
     */
    func tokenize(_ content: String) -> String {
        let str = salt + content
        let data = str.data(using: .utf8, allowLossyConversion: true) ?? Data()
        
        return Data(bytes:
            Array(data.md5()).prefix(8)
            ).base64EncodedString()
    }
}

extension UniqueViewTokenizer {
    /// The key to access the salt from the dataStore. This is named as such for legacy reasons.
    private static let saltKey = "ShopGunSDK.EventsTracker.ClientId"

    /**
     Loads the ViewTokenizer whose `salt` is cached in the dataStore.
     If no salt exist, then creates a new one and saves it to the store.
     If no store is provided then a new salt will be generated, but not stored.
     - parameter dataStore: An instance of a ShopGunSDKDataStore, from which the salt is read, and into which new salts are written.
     */
    static func load(from dataStore: ShopGunSDKDataStore?) -> UniqueViewTokenizer {
        let salt: String
        
        if let storedSalt = dataStore?.get(for: self.saltKey), storedSalt.isEmpty == false {
            salt = storedSalt
        } else {
            // Make a new salt
            salt = UUID().uuidString
            dataStore?.set(value: salt, for: self.saltKey)
        }
        // we are sure salt is non-empty at this point, so no exceptions.
        return UniqueViewTokenizer(salt: salt)!
    }
    
    /**
     First resets the cached salt in the dataStore, then uses `load(from:)` to create a new one.
     - parameter dataStore: An instance of a ShopGunSDKDataStore, from which the salt is read, and into which new salts are written.
     */
    static func reload(from dataStore: ShopGunSDKDataStore?) -> UniqueViewTokenizer {
        dataStore?.set(value: nil, for: self.saltKey)
        return load(from: dataStore)
    }
}
