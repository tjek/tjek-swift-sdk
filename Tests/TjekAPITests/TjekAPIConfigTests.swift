///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import XCTest
@testable import TjekAPI

class TjekAPIConfigTests: XCTestCase {
    
    func testCreatingTjekAPIConfig() throws {
        
        // 1. given
        let testKey = "test-key"
        let testSecret = "test-secret"
        let testClientVersion = "1.2.3"
        let testURL = URL(string: "test-url")!
        let defaultURL = URL(string: "https://squid-api.tjek.com")!
        let defaultClientVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        
        // 2. when
        let fullSettings = try TjekAPI.Config(apiKey: testKey, apiSecret: testSecret, clientVersion: testClientVersion, baseURL: testURL)
        let minimalSettings = try TjekAPI.Config(apiKey: testKey, apiSecret: testSecret)
        
        // 3. then
        XCTAssertEqual(fullSettings.apiKey, testKey)
        XCTAssertEqual(fullSettings.apiSecret, testSecret)
        XCTAssertEqual(fullSettings.clientVersion, testClientVersion)
        XCTAssertEqual(fullSettings.baseURL, testURL)
        
        XCTAssertEqual(minimalSettings.apiKey, testKey)
        XCTAssertEqual(minimalSettings.apiSecret, testSecret)
        XCTAssertEqual(minimalSettings.clientVersion, defaultClientVersion)
        XCTAssertEqual(minimalSettings.baseURL, defaultURL)
        
        // test empty input
        XCTAssertThrowsError(try TjekAPI.Config(apiKey: "", apiSecret: "foo"))
        XCTAssertThrowsError(try TjekAPI.Config(apiKey: "bar", apiSecret: ""))
    }
    
    func testLoadingPlist() throws {
        let expectedHappyConfig = try TjekAPI.Config(apiKey: "<sdk-demo api key>", apiSecret: "<sdk-demo api secret>", clientVersion: "a.b.c", baseURL: URL(string: "https://squid-api.tjek.com")!)
        let testBundle = Bundle.tjekAPITests
        // try to load the updated config
        let happyConfig = try TjekAPI.Config.loadFromPlist(inBundle: testBundle, clientVersion: "a.b.c")
        XCTAssertEqual(happyConfig, expectedHappyConfig)
        
        // test missing file (it's not in main in the tests)
        XCTAssertThrowsError(try TjekAPI.Config.loadFromPlist(inBundle: .main, clientVersion: "x.y.z"))
        
        // test legacy config file
        let legacyFilePath = try XCTUnwrap(testBundle.url(forResource: "ShopGunSDK-Config.plist", withExtension: nil))
        let legacyConfig = try TjekAPI.Config.load(fromLegacyPlist: legacyFilePath, clientVersion: "5.6.7")
        let expectedLegacyConfig = try TjekAPI.Config(apiKey: "<legacy api key>", apiSecret: "<legacy api secret>", clientVersion: "5.6.7", baseURL: URL(string: "https://squid-api.tjek.com")!)
        XCTAssertEqual(legacyConfig, expectedLegacyConfig)
    }
}

private class BundleFinder {}
extension Bundle {
    // we need to do this dance because there is a bug SPM-based tests with resources, and it doesnt build the `.module` accessor.
    static var tjekAPITests: Bundle {
        Bundle(for: BundleFinder.self).subBundle(named: "TjekSDK_TjekAPITests")
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
