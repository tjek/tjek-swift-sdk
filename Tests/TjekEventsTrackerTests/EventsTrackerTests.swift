///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import XCTest
@testable import TjekEventsTracker

class TjekEventsTrackerTests: XCTestCase {
    
    func testLegacyPoolCleaner() {
        
        let legacyCacheFilename = "legacyCache.plist"

        // clear legacy cache
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        try? FileManager.default.removeItem(at: directory!.appendingPathComponent(legacyCacheFilename))
        
        let legacyCacheWriter = EventsCache_v1(fileName: legacyCacheFilename)
        legacyCacheWriter.write(toTail: [("a", Data()),
                                         ("b", Data())])
        
        let expectLegacyCacheEmptied = expectation(description: "Cache should be emptied")
        
        TjekEventsTracker.legacyPoolCleaner(cache: legacyCacheWriter,
                                            dispatchInterval: 1,
                                            baseURL: URL(string: "https://wolf-api.tjek-staging.com")!,
                                            enabled: false) { (shippedCount) in
            if shippedCount == 2 {
                expectLegacyCacheEmptied.fulfill()
            }
        }
        
        waitForExpectations(timeout: 15)
    }
}
