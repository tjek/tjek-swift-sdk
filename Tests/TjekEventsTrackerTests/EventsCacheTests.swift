///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import XCTest
@testable import TjekEventsTracker

struct TestEvent: Codable, CacheableEvent {
    var cacheId: String
    var val: Int
}

class EventsCacheTests: XCTestCase {

    let fileName = "foo.plist"
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    
    override func setUp() {
        super.setUp()
        // clear the cache
        
        try? FileManager.default.removeItem(at: directory!.appendingPathComponent(fileName))
    }
    
    func testReadWrite() {
        
        let maxCnt = 123
        let cacheA = EventsCache<TestEvent>(fileName: fileName, directory: directory, maxCount: maxCnt)
        
        // write-read-write-read past the max count amount
        
        cacheA.write(toTail: (0..<10).map { TestEvent(cacheId: "\($0)", val: $0) })
        cacheA.write(toTail: [])
        XCTAssertEqual(cacheA.objectCount, 10)
        
        cacheA.write(toTail: (10..<200).map { TestEvent(cacheId: "\($0)", val: $0) })
        XCTAssertEqual(cacheA.objectCount, maxCnt)
        
        let readA = cacheA.read(fromHead: 500)
        XCTAssertEqual(readA.count, maxCnt)
        XCTAssertEqual(readA.map { $0.val }, ((200-maxCnt)..<200).map({ $0 }))
        
        cacheA.write(toTail: (200..<400).map { TestEvent(cacheId: "\($0)", val: $0) })
        XCTAssertEqual(cacheA.objectCount, maxCnt)
        
        let readB = cacheA.read(fromHead: 500)
        XCTAssertEqual(readB.count, maxCnt)
        XCTAssertEqual(readB.map { $0.val }, ((400-maxCnt)..<400).map({ $0 }))
    }
    
    func testRemove() {
        
        let cacheA = EventsCache<TestEvent>(fileName: fileName, directory: directory)
        
        cacheA.write(toTail: (0..<10).map { TestEvent(cacheId: "\($0)", val: $0) })
        cacheA.remove(ids: ["0", "1", "3", "6", "99"])
        cacheA.remove(ids: [])
        XCTAssertEqual(cacheA.objectCount, 6)
        let readA = cacheA.read(fromHead: 100)
        XCTAssertEqual(readA.map({ $0.val }), [2, 4, 5, 7, 8, 9] )
    }
}
