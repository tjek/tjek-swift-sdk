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

class SDKEventsTests: XCTestCase {
    
    var tokenizer: UniqueViewTokenizer!
    fileprivate let dataStore = MockSaltDataStore()
    
    override func setUp() {
        self.tokenizer = UniqueViewTokenizer(salt: "salty")!
        
        dataStore.salt = "extra salty"
        EventsTracker.configure(Settings.EventsTracker(appId: "appId_123"),
                                dataStore: self.dataStore)
    }
    
    func testDummy() {
        let testDate = Date(eventTimestamp: 12345)
        
        let event = Event.dummy(timestamp: testDate)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 0)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload, [:])
        
        let nowTimestamp = Date().eventTimestamp
        XCTAssert(abs(Event.dummy().timestamp.eventTimestamp - nowTimestamp) <= 2)
    }
    
    func testPagePublicationOpened() {
        let testDate = Date(eventTimestamp: 12345)
        let event = Event.pagedPublicationOpened("abc123", timestamp: testDate, tokenizer: self.tokenizer.tokenize)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 1)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["pp.id": .string("abc123"),
                        "vt": .string("uSTmB9QXXAc=")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event.pagedPublicationOpened("ølØl5Banana")
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["pp.id": .string("ølØl5Banana"),
                        "vt": .string("KeDNAzqVaTw=")])
    }
    
    func testPagedPublicationPageOpened() {
        let testDate = Date(eventTimestamp: 12345)
        let event = Event.pagedPublicationPageOpened("abc123", pageNumber: 25, timestamp: testDate, tokenizer: self.tokenizer.tokenize)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 2)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["pp.id": .string("abc123"),
                        "ppp.n": .int(25),
                        "vt": .string("xdDQCfzglhA=")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event.pagedPublicationPageOpened("ølØl5Banana", pageNumber: 9999)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["pp.id": .string("ølØl5Banana"),
                        "ppp.n": .int(9999),
                        "vt": .string("OSGOHpF2aus=")])
    }
    
    func testOfferOpened() {
        let testDate = Date(eventTimestamp: 12345)
        let event = Event.offerOpened("offer_123", timestamp: testDate, tokenizer: self.tokenizer.tokenize)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 3)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["of.id": .string("offer_123"),
                        "vt": .string("YNcV9px8d8U=")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event.offerOpened("øffer_321")
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["pp.id": .string("øffer_321"),
                        "vt": .string("fMBunOe6N14=")])
    }
    
    func testClientSessionOpened() {
        let testDate = Date(eventTimestamp: 12345)
        
        let event = Event.clientSessionOpened(timestamp: testDate)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 4)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload, [:])
        
        let nowTimestamp = Date().eventTimestamp
        XCTAssert(abs(Event.clientSessionOpened().timestamp.eventTimestamp - nowTimestamp) <= 2)
    }
    
    func testSearched() {
        let testDate = Date(eventTimestamp: 12345)
        let query = "some løng query\nWith emoji! 🌈 lorum ipsum etc etc"
        let event = Event.searched(for: query, languageCode: "DA", timestamp: testDate, tokenizer: self.tokenizer.tokenize)
        
        XCTAssertFalse(event.id.rawValue.isEmpty)
        XCTAssertEqual(event.type, 5)
        XCTAssertEqual(event.timestamp.eventTimestamp, 12345)
        XCTAssertEqual(event.version, 2)
        XCTAssertEqual(event.payload,
                       ["sea.q": .string(query),
                        "sea.l": .string("DA"),
                        "vt": .string("EAgx/FICBCM=")])
        
        let nowTimestamp = Date().eventTimestamp
        let defaultEvent = Event.searched(for: "", languageCode: nil)
        XCTAssert(abs(defaultEvent.timestamp.eventTimestamp - nowTimestamp) <= 2)
        XCTAssertEqual(defaultEvent.payload,
                       ["sea.q": .string(""),
                        "vt": .string("izp7yPzemjs=")])
    }
    
    func testWeirdViewTokens() {
        func generateContent(_ parts: [Any] ) -> String {
            let contentBytes: Array<UInt8> = parts.reduce(into: []) { bytes, part in
                if let intVal = part as? Int {
                    var intAddr = UInt32(intVal).bigEndian
                    let intData = Data(buffer: UnsafeBufferPointer(start: &intAddr, count: 1))
                    bytes += intData.bytes
                } else if let strData = String(describing: part).data(using: .utf8) {
                    bytes += strData.bytes
                }
            }
            
            return String(data: Data(bytes: contentBytes), encoding: .utf8)!
        }
        
        func tokenizePubContent(_ salt: String, _ pubId: String, _ pageNum: Int32) -> String {
            
            //            let pubIdData = pubId.data(using: .isoLatin1)!
            //
            ////            let pageNumData: Data = {
            //                var pageNumAddr = pageNum.bigEndian
            ////                return withUnsafePointer(to: &pageNumAddr) {
            ////                    Data(bytes: UnsafePointer($0), count: 4)
            ////                }
            ////            }()
            //
            //            let pageNumData = Data(buffer: UnsafeBufferPointer(start: &pageNumAddr, count: 1))
            //
            //            let contentData = Data(bytes: pubIdData.bytes + pageNumData.bytes)
            //            let content = String(data: contentData, encoding: .isoLatin1)!
            
            
            let content = generateContent([pubId, pageNum])
            
            //            let str = salt + content
            
            let str = salt + content
            let strData = str.data(using: .utf8, allowLossyConversion: true) ?? Data()
            
            return Data(bytes: strData.md5().bytes.prefix(8))
                .base64EncodedString()
            
            //            let str = String(data: data, encoding: .isoLatin1)!
            //
            //            let token = Data(bytes:
            //                Data(bytes: str.bytes)
            //                    .md5()
            //                    .bytes
            //                    .prefix(8)
            //                ).base64EncodedString()
            //
            //            return token
        }
        
        //        let tokenA = tokenizePubContent("testSaltA", "pubId-123ABC", 25)
        //        let tokenB = tokenizePubContent("testSaltØ", "pubId-123åü", 9999)
        //
        //        XCTAssertEqual(tokenA, "umft06yayJU=")
        //        XCTAssertEqual(tokenB, "Jb7Sm7q67f4=")
        
        let contentA = generateContent(["pubId-123ABC", 25])
        let contentB = generateContent(["pubId-123åü", 9999])
        
        XCTAssertEqual(UniqueViewTokenizer(salt: "testSaltA")?.tokenize(contentA), "umft06yayJU=")
        // for some reason "testSaltØ" seems to mess with it. salt encoding pre-concat?
        XCTAssertEqual(UniqueViewTokenizer(salt: "testSaltØ")?.tokenize(contentB), "Jb7Sm7q67f4=")
        
        // simple concat fails
        XCTAssertEqual(UniqueViewTokenizer(salt: "testSaltA")?.tokenize("pubId-123ABC"+"\(25)"), "umft06yayJU=")
        XCTAssertEqual(UniqueViewTokenizer(salt: "testSaltØ")?.tokenize("pubId-123åü"+"\(9999)"), "Jb7Sm7q67f4=")

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
