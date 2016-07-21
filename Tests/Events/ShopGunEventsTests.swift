//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import XCTest

@testable import ShopGunSDK

class ShopGunEventsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testFlushTimeout() {
        let tracker = EventsTracker(trackId:"")
        
        // tracker starts with default timeout
        XCTAssert(tracker.flushTimeout == EventsTracker.defaultFlushTimeout)
        
        // changing timeout works
        tracker.flushTimeout = 12345
        XCTAssert(tracker.flushTimeout == 12345)
        
        // reset timeout sets it back to default
        tracker.resetFlushTimeout()
        XCTAssert(tracker.flushTimeout == EventsTracker.defaultFlushTimeout)
        
        
        // changing global default works, and is used by tracker instances
        EventsTracker.defaultFlushTimeout = 23456
        XCTAssert(EventsTracker.defaultFlushTimeout == 23456)
        XCTAssert(tracker.flushTimeout == 23456)
        
        // reseting default works, and tracker instances use it
        EventsTracker.resetDefaultFlushTimeout()
        XCTAssert(EventsTracker.defaultFlushTimeout != 23456)
        XCTAssert(tracker.flushTimeout == EventsTracker.defaultFlushTimeout)
    }
    
//    func testExample() {
//        let tracker = EventsTracker(trackId:"")
//        
//        tracker.trackEvent("x-type", variables: nil)
//    }
    
}
