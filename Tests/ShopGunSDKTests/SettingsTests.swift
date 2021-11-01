//
//  ShopGunSDKTests.swift
//  ShopGunSDKTests
//
//  Created by Laurie Hufford on 29/12/2017.
//  Copyright © 2017 ShopGun. All rights reserved.
//

import XCTest
import Foundation
@testable import ShopGunSDK

class SettingsTests: XCTestCase {

    // MARK: - GraphAPI Settings
    
    func testCreatingGraphAPISettings() {
        
        // 1. given
        let testKey = "test-key"
        let testURL = URL(string: "test-url")!
        let defaultURL = URL(string: "https://graph.service.shopgun.com")!
        
        // 2. when
        guard let fullSettings = try? Settings.GraphAPI(key: testKey, baseURL: testURL) else { return }
        guard let minimalSettings = try? Settings.GraphAPI(key: testKey) else { return }
        
        // 3. then
        XCTAssertEqual(fullSettings.key, testKey)
        XCTAssertEqual(fullSettings.baseURL, testURL)
        
        XCTAssertEqual(minimalSettings.key, testKey)
        XCTAssertEqual(minimalSettings.baseURL, defaultURL)
    }
    
    func testDecodingGraphAPISettings() {
        
        // 1. given
        let testKey = "test-key"
        let testURL = URL(string: "test-url")!
        let defaultURL = URL(string: "https://graph.service.shopgun.com")!
        let fullJson = """
            {
            "key": "\(testKey)",
            "baseURL": "\(testURL)"
            }
            """.data(using: .utf8)!
        
        let minimalJson = """
            {
            "key": "\(testKey)"
            }
            """.data(using: .utf8)!
        
        do {
            // 2. when
            let fullSettings = try JSONDecoder().decode(Settings.GraphAPI.self, from: fullJson)
            let minimalSettings = try JSONDecoder().decode(Settings.GraphAPI.self, from: minimalJson)
            
            // 3. then
            XCTAssertEqual(fullSettings.key, testKey)
            XCTAssertEqual(fullSettings.baseURL, testURL)
            
            XCTAssertEqual(minimalSettings.key, testKey)
            XCTAssertEqual(minimalSettings.baseURL, defaultURL)
        } catch let error {
            XCTAssert(false, "Unable to decode settings: \(error.localizedDescription)")
        }
    }
    
}
