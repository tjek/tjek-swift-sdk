///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import XCTest
@testable import TjekEventsTracker
import TjekAPI
import TjekUtils

extension SaltStore {
    static func local(initial: String? = nil) -> SaltStore {
        var salt = initial
        return SaltStore(get: { salt }, set: { salt = $0 })
    }
}

// https://gist.github.com/tbug/88c169d2ac5f5bebbf59211eb35ff23a
class SDKEventsTests: XCTestCase {
    
    // A custom tokenizer
    var tokenizer: UniqueViewTokenizer!
    
    override func setUp() {
        super.setUp()
        
        self.tokenizer = UniqueViewTokenizer(salt: "salty")!
        
        // initialize the shared tracker, as this is used as the default tokenizer.
        do {
            try TjekEventsTracker.initialize(config: .init(trackId: "appId_123"), saltStore: .local(initial: "myhash"))
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func testDummy() {
        let testDate = Date(eventTimestamp: 12345)
        
        let event = Event._dummy(timestamp: testDate)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 0)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload, [:])
        
        let nowTimestamp = Date().eventTimestamp
        XCTAssert(abs(Event._dummy().timestamp.eventTimestamp - nowTimestamp) <= 2)
    }
    
    func testPagePublicationOpened() {
        let testDate = Date(eventTimestamp: 12345)
        let event = Event._pagedPublicationOpened("pub1", timestamp: testDate, tokenizer: self.tokenizer.tokenize)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 1)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["pp.id": .string("pub1"),
                        "vt": .string("HUdC076YIL8=")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event._pagedPublicationOpened("😁")
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["pp.id": .string("😁"),
                        "vt": .string("POcLWv7/N4Q=")])
    }
    
    func testPagedPublicationPageOpened() {
        let testDate = Date(eventTimestamp: 12345)
        let event = Event._pagedPublicationPageOpened("pub1", pageNumber: 1, timestamp: testDate, tokenizer: self.tokenizer.tokenize)

        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 2)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["pp.id": .string("pub1"),
                        "ppp.n": .int(1),
                        "vt": .string("xX+BAiu1Nmo=")])

        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event.pagedPublicationPageOpened("ølØl5Banana", pageNumber: 9999)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["pp.id": .string("ølØl5Banana"),
                        "ppp.n": .int(9999),
                        "vt": .string("JR8kZFk7M+Y=")])
        
        XCTAssertEqual(Event.pagedPublicationPageOpened("pub1", pageNumber: 1).payload,
                       ["pp.id": .string("pub1"),
                        "ppp.n": .int(1),
                        "vt": .string("GKtJxfAxRZI=")])
        
        XCTAssertEqual(Event.pagedPublicationPageOpened("pub1", pageNumber: 9999).payload,
                       ["pp.id": .string("pub1"),
                        "ppp.n": .int(9999),
                        "vt": .string("VwMOrDD8zMk=")])
    }
    
    func testOfferOpened() {
        let testDate = Date(eventTimestamp: 12345)
        let event = Event._offerInteraction("offer_123", timestamp: testDate, action: "action_123", screenName: "screenName_567", tokenizer: self.tokenizer.tokenize)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 3)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["of.id": .string("offer_123"),
                        "a": .string("action_123"),
                        "s": .string("screenName_567"),
                        "vt": .string("YNcV9px8d8U=")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event.offerInteraction("øffer_321", action: nil, screenName: nil)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["of.id": .string("øffer_321"),
                        "vt": .string("ryYm+eb1bUU=")])
    }
    
    func testSearched() {
        let testDate = Date(eventTimestamp: 12345)
        let query = "Søme Very Long Séarch string 🌈"
        let event = Event._searched(for: query, languageCode: "DA", timestamp: testDate, tokenizer: self.tokenizer.tokenize)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 5)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["sea.q": .string(query),
                        "sea.l": .string("DA"),
                        "vt": .string("erHTNwqSrLY=")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event._searched(for: "", languageCode: nil)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["sea.q": .string(""),
                        "vt": .string("2oEIMMzybMM=")])
        
        XCTAssertEqual(Event.searched(for: "my search string", languageCode: "a").payload,
                       ["sea.q": .string("my search string"),
                        "sea.l": .string("a"),
                        "vt": .string("bNOIlf+nAAU=")])
        
        XCTAssertEqual(Event.searched(for: "my search string 😁", languageCode: nil).payload,
                       ["sea.q": .string("my search string 😁"),
                        "vt": .string("+OJqwh68nIk=")])
        
        XCTAssertEqual(Event.searched(for: "øl og æg", languageCode: nil).payload,
                       ["sea.q": .string("øl og æg"),
                        "vt": .string("NTgj68OWnbc=")])
    }
    
    func testOfferOpenedAfterSearch() {
        let testDate = Date(eventTimestamp: 12345)
        let query = "Søme Very Long Séarch string 🌈"
        let event = Event._offerOpenedAfterSearch(offerId: "offer_123", query: query, languageCode: "DA", timestamp: testDate)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 7)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["sea.q": .string(query),
                        "sea.l": .string("DA"),
                        "of.id": .string("offer_123")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event._offerOpenedAfterSearch(offerId: "abc123", query: "", languageCode: nil)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["sea.q": .string(""),
                        "of.id": .string("abc123")])
    }
    
    func testFirstOfferOpenedAfterSearch() {
        let testDate = Date(eventTimestamp: 12345)
        let query = "Another Very Long Séarch string 🌈"
        let offerIds = ["b", "a", "c"].map(OfferId.init(rawValue:))
        let event = Event._firstOfferOpenedAfterSearch(offerId: "offer_123", precedingOfferIds: offerIds, query: query, languageCode: "DA", timestamp: testDate)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 6)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["sea.q": .string(query),
                        "sea.l": .string("DA"),
                        "of.id": .string("offer_123"),
                        "of.ids": .array([.string("b"), .string("a"), .string("c")])
                        ])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event._firstOfferOpenedAfterSearch(offerId: "abc123", precedingOfferIds: [], query: "", languageCode: nil)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["sea.q": .string(""),
                        "of.id": .string("abc123"),
                        "of.ids": .array([])
                        ])
        
        let manyOfferIds = Array(50..<250).map({ OfferId(rawValue: String($0)) })
        
        let clampedOfferIds = manyOfferIds.prefix(100).map({ JSONValue.string($0.rawValue) })
        
        let bigEvent = Event._firstOfferOpenedAfterSearch(offerId: "abc123", precedingOfferIds: manyOfferIds, query: "", languageCode: nil)
        
        XCTAssertEqual(bigEvent.payload,
                       ["sea.q": .string(""),
                        "of.id": .string("abc123"),
                        "of.ids": .array(clampedOfferIds)
            ])
    }
    
    func testSearchResultsViewed() {
        let testDate = Date(eventTimestamp: 12345)
        let query = "Søme Very Long Séarch string 🌈"
        let event = Event._searchResultsViewed(query: query, languageCode: "DA", resultsViewedCount: 5, timestamp: testDate)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 9)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["sea.q": .string(query),
                        "sea.l": .string("DA"),
                        "sea.v": .int(5)])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event._searchResultsViewed(query: "", languageCode: nil, resultsViewedCount: 1)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["sea.q": .string(""),
                        "sea.v": .int(1)])
    }
}
