//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation
import UIKit

@objc(SGNSDKConfig)
public class SDKConfig : NSObject {
    
    public override init() {
        super.init()
        // make sure that client & sessionIds are initialized as the very first thing.
        _ = SDKConfig.clientId
        _ = SDKConfig.sessionId
    }
    
    // MARK: -
    /**
     *  The `appId` is sent with all requests the SDK. 
     *  It lets ShopGun know who is making the requests.
     *  It will be read from the "APP_ID" key in 'ShopGunSDK-Info.plist', that you should include in your bundle.
     *
     *  If you do not wish to use this .plist file you can instead assign this key manually:
     *  `ShopGunSDK.SDKConfig.appId = "..."`
     *
     *  Note, if SDKConfig.appId is used before it has been configured it will assert.
     */
    public static var appId : String? {
        get {
            if _appId == nil {
                _appId = Utils.fetchConfigValue(for:"APP_ID") as? String
            }
            
            assert(_appId != nil, "You must define a ShopGun `APP_ID` in your ShopGunSDK-Info.plist, or with `ShopGunSDK.SDKConfig.appId = ...`")
            return _appId
        }
        set {
            _appId = newValue
        }
    }
    fileprivate static var _appId : String?
    
    
    
    
    
    // MARK: -
    
    /// ClientId will be generated on first use, and then saved to the keychain
    public static var clientId : String {
        if _clientId == nil {
            if let cachedClientId = Utils.getKeychainString("ClientId") {
                _clientId = cachedClientId
            }
            else {
                _clientId = UUID().uuidString
                
                // fire event whenever clientId is created
                DispatchQueue.main.async {
                    EventsTracker.globalTracker?.trackEventSync("first-client-session-opened", properties: nil)
                }
                
                _ = Utils.setKeychainString(_clientId!, key: "ClientId")
            }
        }
        return _clientId!
    }
    
    public static func resetClientId() {
        _ = Utils.removeKeychainObject("ClientId")
        _clientId = nil
    }
    
    fileprivate static var _clientId : String?
    
    
    
    
    // MARK: -
    
    /// sessionId is a UUID that is reset every time the app becomes active.
    public static var sessionId : String {
        return _sessionHandler.sessionId
    }
    
    fileprivate static let _sessionHandler:SessionLifecycleHandler = SessionLifecycleHandler()
    
    fileprivate class SessionLifecycleHandler {
        
        /// sessionId is lazily generated if nil
        fileprivate var _sessionId:String?
        var sessionId:String {
            if _sessionId == nil {
                
                _sessionId = UUID().uuidString
                
                // make sure that the `first-client-session-opened` is triggered first
                _ = SDKConfig.clientId
                
                // fire event whenever sessionId is created
                DispatchQueue.main.async {
                    EventsTracker.globalTracker?.trackEventSync("client-session-opened", properties: nil)
                }
            }
            return _sessionId!
        }
        init() {
            NotificationCenter.default.addObserver(self, selector:#selector(appDidBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
            NotificationCenter.default.addObserver(self, selector:#selector(appDidEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        }
        deinit {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        }
        
        
        fileprivate var isInBackground:Bool = false
        
        @objc
        fileprivate func appDidBecomeActive(_ notification:Notification) {
            if isInBackground {
                // force a reset of the sessionId
                _sessionId = nil
                _ = sessionId
            }
            isInBackground = false
                
        }
        @objc
        fileprivate func appDidEnterBackground(_ notification:Notification) {
            isInBackground = true
        }
    }
}
