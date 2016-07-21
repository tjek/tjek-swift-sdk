//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

#import <XCTest/XCTest.h>

@import ShopGunSDK;

@interface ShopGunEventsTests_ObjC : XCTestCase

@end

@implementation ShopGunEventsTests_ObjC

- (void)setUp {
    [super setUp];
    
    SGNSDKConfig.appId = @"sdfg";
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testFlushTimeout {
    
    SGNEventsTracker* tracker = [[SGNEventsTracker alloc] initWithTrackId:@""];
    
    // tracker starts with default timeout
    XCTAssert(tracker.flushTimeout == SGNEventsTracker.defaultFlushTimeout);
    
    // changing timeout works
    tracker.flushTimeout = 12345;
    XCTAssert(tracker.flushTimeout == 12345);
    
    // reset timeout sets it back to default
    [tracker resetFlushTimeout];
    XCTAssert(tracker.flushTimeout == SGNEventsTracker.defaultFlushTimeout);
    
    
    // changing global default works, and is used by tracker instances
    SGNEventsTracker.defaultFlushTimeout = 23456;
    XCTAssert(SGNEventsTracker.defaultFlushTimeout == 23456);
    XCTAssert(tracker.flushTimeout == 23456);
    
    // reseting default works, and tracker instances use it
    [SGNEventsTracker resetDefaultFlushTimeout];
    XCTAssert(SGNEventsTracker.defaultFlushTimeout != 23456);
    XCTAssert(tracker.flushTimeout == SGNEventsTracker.defaultFlushTimeout);
}

@end
