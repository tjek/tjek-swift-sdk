///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

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
        return Data(Array(data.md5()).prefix(8)).base64EncodedString()
    }
}

public struct SaltStore {
    let get: () -> String?
    let set: (String?) -> Void
}

extension UniqueViewTokenizer {
    /**
     Loads the ViewTokenizer whose `salt` is cached in the dataStore.
     If no salt exist, then creates a new one and saves it to the store.
     - parameter saltStore: A struct that knows how to read & write the salt values.
     */
    static func load(from saltStore: SaltStore) -> UniqueViewTokenizer {
        let salt: String
        
        if let storedSalt = saltStore.get(), storedSalt.isEmpty == false {
            salt = storedSalt
        } else {
            // Make a new salt
            salt = UUID().uuidString
            saltStore.set(salt)
        }
        // we are sure salt is non-empty at this point, so no exceptions.
        return UniqueViewTokenizer(salt: salt)!
    }
    
    /**
     First resets the cached salt in the dataStore, then uses `load(from:)` to create a new one.
     - parameter saltStore: A struct that knows how to read & write the salt values.
     */
    static func reload(from saltStore: SaltStore) -> UniqueViewTokenizer {
        saltStore.set(nil)
        return load(from: saltStore)
    }
}
