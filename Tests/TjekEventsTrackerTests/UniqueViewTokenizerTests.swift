///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import XCTest
@testable import TjekEventsTracker

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
        var salt: String?
        
        let passThruStore = SaltStore(
            get: { salt },
            set: { salt = $0 }
        )
        
        // salts loaded from the datastore persist
        salt = "foo"
        XCTAssertEqual(UniqueViewTokenizer.load(from: passThruStore).salt, "foo")
        XCTAssertEqual(UniqueViewTokenizer.load(from: passThruStore).salt, "foo")
        
        // dataStore with empty string should generate new salt
        salt = ""
        let emptySaltTokenizerA = UniqueViewTokenizer.load(from: passThruStore)
        let emptySaltTokenizerB = UniqueViewTokenizer.load(from: passThruStore)
        XCTAssertFalse(emptySaltTokenizerA.salt.isEmpty)
        XCTAssertEqual(emptySaltTokenizerA.salt, emptySaltTokenizerB.salt)
        
        // load from empty datastore leads to new non-empty token, and that token persists to future loads
        salt = nil
        let tokenizerA = UniqueViewTokenizer.load(from: passThruStore)
        XCTAssertFalse(tokenizerA.salt.isEmpty)
        let tokenizerB = UniqueViewTokenizer.load(from: passThruStore)
        XCTAssertEqual(tokenizerA.salt, tokenizerB.salt)
    }
    
    func testSaltReloading() {
        var salt: String? = "foo"
        let passThruStore = SaltStore(
            get: { salt },
            set: { salt = $0 }
        )
        
        // reloading salt means a new one is generated.
        let tokenizerA = UniqueViewTokenizer.load(from: passThruStore)
        let tokenizerB = UniqueViewTokenizer.reload(from: passThruStore)
        let tokenizerC = UniqueViewTokenizer.load(from: passThruStore)
        XCTAssertEqual(tokenizerA.salt, "foo")
        XCTAssertNotEqual(tokenizerB.salt, tokenizerA.salt)
        XCTAssertFalse(tokenizerB.salt.isEmpty)
        XCTAssertEqual(tokenizerA.salt, "foo")
        XCTAssertEqual(tokenizerB.salt, tokenizerC.salt)
    }
}
