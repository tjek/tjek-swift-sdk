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

    // MARK: - CoreAPI Settings
    
    func testCreatingCoreAPISettings() {
        
        // 1. given
        let testKey = "test-key"
        let testSecret = "test-secret"
        let testURL = URL(string: "test-url")!
        let defaultURL = URL(string: "https://api.etilbudsavis.dk")!
        
        // 2. when
        let fullSettings = Settings.CoreAPI(key: testKey, secret: testSecret, baseURL: testURL)
        let minimalSettings = Settings.CoreAPI(key: testKey, secret: testSecret)
        
        // 3. then
        XCTAssertEqual(fullSettings.key, testKey)
        XCTAssertEqual(fullSettings.secret, testSecret)
        XCTAssertEqual(fullSettings.baseURL, testURL)
        
        XCTAssertEqual(minimalSettings.key, testKey)
        XCTAssertEqual(minimalSettings.secret, testSecret)
        XCTAssertEqual(minimalSettings.baseURL, defaultURL)
    }
    
    func testDecodingCoreAPISettings() {
        
        // 1. given
        let testKey = "test-key"
        let testSecret = "test-secret"
        let testURL = URL(string: "test-url")!
        let defaultURL = URL(string: "https://api.etilbudsavis.dk")!
        let fullJson = """
        {
            "key": "\(testKey)",
            "secret": "\(testSecret)",
            "baseURL": "\(testURL)"
        }
        """.data(using: .utf8)!
        
        let minimalJson = """
        {
        "key": "\(testKey)",
        "secret": "\(testSecret)"
        }
        """.data(using: .utf8)!
        
        do {
            // 2. when
            let fullSettings = try JSONDecoder().decode(Settings.CoreAPI.self, from: fullJson)
            let minimalSettings = try JSONDecoder().decode(Settings.CoreAPI.self, from: minimalJson)
            
            // 3. then
            XCTAssertEqual(fullSettings.key, testKey)
            XCTAssertEqual(fullSettings.secret, testSecret)
            XCTAssertEqual(fullSettings.baseURL, testURL)
            
            XCTAssertEqual(minimalSettings.key, testKey)
            XCTAssertEqual(minimalSettings.secret, testSecret)
            XCTAssertEqual(minimalSettings.baseURL, defaultURL)
        } catch let error {
            XCTAssert(false, "Unable to decode settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - GraphAPI Settings
    
    func testCreatingGraphAPISettings() {
        
        // 1. given
        let testKey = "test-key"
        let testURL = URL(string: "test-url")!
        let defaultURL = URL(string: "https://graph.service.shopgun.com")!
        
        // 2. when
        let fullSettings = Settings.GraphAPI(key: testKey, baseURL: testURL)
        let minimalSettings = Settings.GraphAPI(key: testKey)
        
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
    
    // MARK: - EventsTracker Settings
    
    func testCreatingEventsTrackerSettings() {
        
        // 1. given
        let testAppId = Settings.EventsTracker.AppIdentifier(rawValue: "test-appId")
        let testURL = URL(string: "test-url")!
        let testDispatchInterval: TimeInterval = 111
        let testDispatchLimit: Int = 222
        let testEnabled: Bool = false
        
        let defaultURL = URL(string: "https://events.service.shopgun.com")!
        let defaultDispatchInterval: TimeInterval = 120
        let defaultDispatchLimit: Int = 100
        let defaultEnabled: Bool = true
        
        // 2. when
        let fullSettings = Settings.EventsTracker(appId: testAppId, baseURL: testURL, dispatchInterval: testDispatchInterval, dispatchLimit: testDispatchLimit, enabled: testEnabled)
        let minimalSettings = Settings.EventsTracker(appId: testAppId)
        
        // 3. then
        XCTAssertEqual(fullSettings.appId, testAppId)
        XCTAssertEqual(fullSettings.baseURL, testURL)
        XCTAssertEqual(fullSettings.dispatchInterval, testDispatchInterval)
        XCTAssertEqual(fullSettings.dispatchLimit, testDispatchLimit)
        XCTAssertEqual(fullSettings.enabled, testEnabled)
        
        XCTAssertEqual(minimalSettings.appId, testAppId)
        XCTAssertEqual(minimalSettings.baseURL, defaultURL)
        XCTAssertEqual(minimalSettings.dispatchInterval, defaultDispatchInterval)
        XCTAssertEqual(minimalSettings.dispatchLimit, defaultDispatchLimit)
        XCTAssertEqual(minimalSettings.enabled, defaultEnabled)
    }
    
    func testDecodingEventsTrackerSettings() {
        
        // 1. given
        let testAppId = Settings.EventsTracker.AppIdentifier(rawValue: "test-appId")
        let testURL = URL(string: "test-url")!
        let testDispatchInterval: TimeInterval = 111
        let testDispatchLimit: Int = 222
        let testEnabled: Bool = false
        
        let defaultURL = URL(string: "https://events.service.shopgun.com")!
        let defaultDispatchInterval: TimeInterval = 120
        let defaultDispatchLimit: Int = 100
        let defaultEnabled: Bool = true
        
        let fullJson = """
            {
            "appId": "\(testAppId)",
            "baseURL": "\(testURL)",
            "dispatchInterval": \(testDispatchInterval),
            "dispatchLimit": \(testDispatchLimit),
            "enabled": \(testEnabled)
            }
            """.data(using: .utf8)!
        
        let minimalJson = """
            {
            "appId": "\(testAppId)"
            }
            """.data(using: .utf8)!
        
        do {
            // 2. when
            let fullSettings = try JSONDecoder().decode(Settings.EventsTracker.self, from: fullJson)
            let minimalSettings = try JSONDecoder().decode(Settings.EventsTracker.self, from: minimalJson)
            
            // 3. then
            XCTAssertEqual(fullSettings.appId, testAppId)
            XCTAssertEqual(fullSettings.baseURL, testURL)
            XCTAssertEqual(fullSettings.dispatchInterval, testDispatchInterval)
            XCTAssertEqual(fullSettings.dispatchLimit, testDispatchLimit)
            XCTAssertEqual(fullSettings.enabled, testEnabled)
            
            XCTAssertEqual(minimalSettings.appId, testAppId)
            XCTAssertEqual(minimalSettings.baseURL, defaultURL)
            XCTAssertEqual(minimalSettings.dispatchInterval, defaultDispatchInterval)
            XCTAssertEqual(minimalSettings.dispatchLimit, defaultDispatchLimit)
            XCTAssertEqual(minimalSettings.enabled, defaultEnabled)
        } catch let error {
            XCTAssert(false, "Unable to decode settings: \(error.localizedDescription)")
        }
    }
}
