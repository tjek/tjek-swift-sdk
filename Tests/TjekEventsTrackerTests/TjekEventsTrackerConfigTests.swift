///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import XCTest
@testable import TjekEventsTracker

class TjekEventsTrackerConfigTests: XCTestCase {
    
    func testCreatingTjekTrackerConfig() throws {
        let fullSettings = try TjekEventsTracker.Config(appId: "foo", baseURL: URL(string: "test-url")!, dispatchInterval: 999, dispatchLimit: 123, enabled: false)
        
        XCTAssertEqual(fullSettings.appId, "foo")
        XCTAssertEqual(fullSettings.baseURL, URL(string: "test-url")!)
        XCTAssertEqual(fullSettings.dispatchInterval, 999)
        XCTAssertEqual(fullSettings.dispatchLimit, 123)
        XCTAssertEqual(fullSettings.enabled, false)
        
        let minimalSettings = try TjekEventsTracker.Config(appId: "bar")
        
        XCTAssertEqual(minimalSettings.appId, "bar")
        XCTAssertEqual(minimalSettings.baseURL, URL(string: "https://wolf-api.tjek.com")!)
        XCTAssertEqual(minimalSettings.dispatchInterval, 120)
        XCTAssertEqual(minimalSettings.dispatchLimit, 100)
        XCTAssertEqual(minimalSettings.enabled, true)
        
        // test empty input
        XCTAssertThrowsError(try TjekEventsTracker.Config(appId: ""))
    }
    
    func testLoadingPlist() throws {
        let expectedHappyConfig = try TjekEventsTracker.Config(appId: "<sdk-demo appId>", baseURL: URL(string: "https://wolf-api.tjek.com")!, dispatchInterval: 120.0, dispatchLimit: 100, enabled: true)
        
        let testBundle = Bundle.tjekEventsTrackerTests
        // try to load the updated config
        let happyConfig = try TjekEventsTracker.Config.loadFromPlist(inBundle: testBundle)
        XCTAssertEqual(happyConfig, expectedHappyConfig)
        
        // test missing file (it's not in main in the tests)
        XCTAssertThrowsError(try TjekEventsTracker.Config.loadFromPlist(inBundle: .main))
    }
}

private class BundleFinder {}
extension Bundle {
    // we need to do this dance because there is a bug SPM-based tests with resources, and it doesnt build the `.module` accessor.
    static var tjekEventsTrackerTests: Bundle {
        Bundle(for: BundleFinder.self).subBundle(named: "TjekSDK_TjekEventsTrackerTests")
    }
}

extension Bundle {
    func subBundle(named bundleName: String) -> Bundle {
        let bundlePath = self.resourceURL?.appendingPathComponent(bundleName + ".bundle")
        if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
            return bundle
        }
        fatalError("unable to find bundle named '\(bundleName)'")
    }
}
