//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import XCTest
@testable import ShopGunSDK

class UniqueViewTokenizerTests: XCTestCase {
    
    func testExpectedTokens() {
        // Empty salts not allowed
        XCTAssertNil(UniqueViewTokenizer(salt: ""))
        
        let tokenizer = UniqueViewTokenizer(salt: "selfmade")
        
        XCTAssertNotNil(tokenizer)
        
        XCTAssertEqual(tokenizer?.tokenize("test" + "1"), "29g0Lh6ViFc=")
        XCTAssertEqual(tokenizer?.tokenize("go" + "go" + "2" + "nice" + "øl"), "nAu6OWTIWnc=")
        XCTAssertEqual(tokenizer?.tokenize("🌈"), "Pdz8/0+PiYk=")
        XCTAssertEqual(tokenizer?.tokenize(""), "K6ZncTGDSjs=")
    }
    
    func testSaltLoading() {
        let dataStore = MockSaltDataStore()
        
        // salts loaded from the datastore persist
        dataStore.salt = "foo"
        XCTAssertEqual(UniqueViewTokenizer.load(from: dataStore).salt, "foo")
        XCTAssertEqual(UniqueViewTokenizer.load(from: dataStore).salt, "foo")
        
        // dataStore with empty string should generate new salt
        dataStore.salt = ""
        let emptySaltTokenizerA = UniqueViewTokenizer.load(from: dataStore)
        let emptySaltTokenizerB = UniqueViewTokenizer.load(from: dataStore)
        XCTAssertFalse(emptySaltTokenizerA.salt.isEmpty)
        XCTAssertEqual(emptySaltTokenizerA.salt, emptySaltTokenizerB.salt)
        
        // load from empty datastore leads to new non-empty token, and that token persists to future loads
        dataStore.salt = nil
        let tokenizerA = UniqueViewTokenizer.load(from: dataStore)
        XCTAssertFalse(tokenizerA.salt.isEmpty)
        let tokenizerB = UniqueViewTokenizer.load(from: dataStore)
        XCTAssertEqual(tokenizerA.salt, tokenizerB.salt)
        
        // load from nil datastore must give non-empty & unique salt
        let nilStoreTokenizerA = UniqueViewTokenizer.load(from: nil)
        let nilStoreTokenizerB = UniqueViewTokenizer.load(from: nil)
        XCTAssertFalse(nilStoreTokenizerA.salt.isEmpty)
        XCTAssertFalse(nilStoreTokenizerB.salt.isEmpty)
        XCTAssertNotEqual(nilStoreTokenizerA.salt, nilStoreTokenizerB.salt)
    }
    func testSaltReloading() {
        let dataStore = MockSaltDataStore()
        dataStore.salt = "foo"
        
        // reloading salt means a new one is generated.
        let tokenizerA = UniqueViewTokenizer.load(from: dataStore)
        let tokenizerB = UniqueViewTokenizer.reload(from: dataStore)
        let tokenizerC = UniqueViewTokenizer.load(from: dataStore)
        XCTAssertEqual(tokenizerA.salt, "foo")
        XCTAssertNotEqual(tokenizerB.salt, tokenizerA.salt)
        XCTAssertFalse(tokenizerB.salt.isEmpty)
        XCTAssertEqual(tokenizerA.salt, "foo")
        XCTAssertEqual(tokenizerB.salt, tokenizerC.salt)
    }
}

fileprivate class MockSaltDataStore: ShopGunSDKDataStore {
    var salt: String? = nil
    
    func set(value: String?, for key: String) {
        guard key == "ShopGunSDK.EventsTracker.ClientId" else { return }
        salt = value
    }
    func get(for key: String) -> String? {
        guard key == "ShopGunSDK.EventsTracker.ClientId" else { return nil }
        return salt
    }
}
