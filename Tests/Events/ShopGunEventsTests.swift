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
    
//    func testFlushTimeout() {
//        let tracker = EventsTracker(trackId:"")
//
//        // tracker starts with default timeout
//        XCTAssert(tracker.dispatchInterval == EventsTracker.defaultFlushTimeout)
//
//        // changing timeout works
//        tracker.dispatchInterval = 12345
//        XCTAssert(tracker.dispatchInterval == 12345)
//
//        // reset timeout sets it back to default
//        tracker.resetFlushTimeout()
//        XCTAssert(tracker.dispatchInterval == EventsTracker.defaultFlushTimeout)
//
//
//        // changing global default works, and is used by tracker instances
//        EventsTracker.defaultFlushTimeout = 23456
//        XCTAssert(EventsTracker.defaultFlushTimeout == 23456)
//        XCTAssert(tracker.dispatchInterval == 23456)
//
//        // reseting default works, and tracker instances use it
//        EventsTracker.resetDefaultFlushTimeout()
//        XCTAssert(EventsTracker.defaultFlushTimeout != 23456)
//        XCTAssert(tracker.dispatchInterval == EventsTracker.defaultFlushTimeout)
//    }
    
    func testTrackEvent() {
        //print (SDKConfig.clientId)
        
        //let tracker = EventsTracker(trackId:"myTrackId")
        
        //tracker.trackEvent("x-type", properties: ["foo":"bar"])
    }
    
}
