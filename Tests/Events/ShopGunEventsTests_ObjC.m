//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

#import <XCTest/XCTest.h>

@import ShopGunCore;
@import ShopGunEvents;

@interface ShopGunEventsTests_ObjC : XCTestCase

@end

@implementation ShopGunEventsTests_ObjC

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    SGNEventsTracker* tracker = [[SGNEventsTracker alloc] initWithTrackId:@"sdfg"];
    
    [tracker trackEvent:@"x-type" variables:@{}];
}


@end
