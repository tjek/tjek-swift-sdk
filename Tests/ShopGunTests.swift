//
//  ShopGunSDKTests.swift
//  ShopGunSDKTests
//
//  Created by Laurie Hufford on 29/12/2017.
//  Copyright © 2017 ShopGun. All rights reserved.
//

import XCTest
@testable import ShopGunSDK

class ShopGunTests: XCTestCase {
    
    private func resetSDK() {
        let emptySettings = ShopGun.Settings(coreAPI: nil, eventsTracker: nil, sharedKeychainGroupId: nil)
        
        ShopGun.configure(settings: emptySettings)
    }
    
    // After resetting the SDK, are the components unavailable
    func testEmptyConfiguration() {
        resetSDK()
        
        XCTAssert(ShopGun.hasCoreAPI == false)
        XCTAssert(ShopGun.hasEventsTracker == false)
    }
    
    // Are settings correctly passed to sdk components with configuring
    func testCompleteConfiguration() {
        resetSDK()

        let coreAPISettings = CoreAPI.Settings(key: "test_key", secret: "test_secret", baseURL: URL(string: "https://test.shopgun.com")!)
        let eventsTrackerSettings = EventsTracker.Settings(trackId: "test_trackId", baseURL: URL(string: "https://test.shopgun.com")!, dispatchInterval: 123, dispatchLimit: 456, dryRun: true)
        
        let fullSettings = ShopGun.Settings(coreAPI: coreAPISettings, eventsTracker: eventsTrackerSettings, sharedKeychainGroupId: nil)
        
        ShopGun.configure(settings: fullSettings)
        
        XCTAssert(ShopGun.hasCoreAPI == true)
        XCTAssert(ShopGun.hasEventsTracker == true)
        
        XCTAssert(ShopGun.coreAPI.settings.key == coreAPISettings.key)
        XCTAssert(ShopGun.coreAPI.settings.secret == coreAPISettings.secret)
        XCTAssert(ShopGun.coreAPI.settings.baseURL == coreAPISettings.baseURL)
        
        XCTAssert(ShopGun.eventsTracker.settings.trackId == eventsTrackerSettings.trackId)
        XCTAssert(ShopGun.eventsTracker.settings.baseURL == eventsTrackerSettings.baseURL)
        XCTAssert(ShopGun.eventsTracker.settings.dispatchInterval == eventsTrackerSettings.dispatchInterval)
        XCTAssert(ShopGun.eventsTracker.settings.dispatchLimit == eventsTrackerSettings.dispatchLimit)
        XCTAssert(ShopGun.eventsTracker.settings.dryRun == eventsTrackerSettings.dryRun)
    }
}
