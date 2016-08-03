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
import Valet

@objc(SGNSDKConfig)
public class SDKConfig : NSObject {
    
    public static var appId : String? {
        get {
            if let appId = _overrideAppId ?? _globalAppId {
                return appId
            }
            
            // TODO: make non-optional?
            
            // TODO: more details in error message.
            print("You must define a ShopGun `appId` in your info.plist or SDKConfig")
            
            // TODO: maybe consider asserting?
            // assert(appId != nil, "You must define a ShopGun appId in your info.plist or SDKConfig")
            return nil
        }
        set {
            _overrideAppId = newValue
        }
    }
    
    // ClientId will be generated on first use, and then saved to the keychain
    public static var clientId : String {
        if _clientId == nil {
            if let cachedClientId = keychainValet?.stringForKey("ClientId") {
                _clientId = cachedClientId
            }
            else {
                _clientId = NSUUID().UUIDString
                keychainValet?.setString(_clientId!, forKey: "ClientId")
            }
        }
        return _clientId!
    }
    
    public static func resetClientId() {
        keychainValet?.removeObjectForKey("ClientId")
        _clientId = nil
    }
    
    
    
    // sessionId exists only while the app is in an active state, and reset when the app goes into the background.
    public static var sessionId : String {
        return _sessionHandler.sessionUUID
    }
    
    
    
    
    
    // MARK: Private
    
    private static var _overrideAppId : String? = nil
    private static let _globalAppId : String? = {
        return Utils.fetchInfoPlistValue("AppId") as? String
    }()
    
    private static let keychainValet:VALValet? = VALValet(identifier: "com.shopgun.ios.sdk.keychain", accessibility: .AfterFirstUnlock)
    private static var _clientId : String?

    private static let _sessionHandler:SessionLifecycleHandler = SessionLifecycleHandler()
    private class SessionLifecycleHandler {
        
        /// sessionUUID is lazily generated if nil
        private var _sessionUUID:String?
        var sessionUUID:String {
            if _sessionUUID == nil {
                _sessionUUID = NSUUID().UUIDString
            }
            return _sessionUUID!
        }
        
        init() {
            // force a re-creation of the sessionUUID
            sessionUUID
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(SessionLifecycleHandler.appDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(SessionLifecycleHandler.appDidEnterBackground), name: UIApplicationDidEnterBackgroundNotification, object: nil)


        }
        deinit {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object: nil)
            NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidEnterBackgroundNotification, object: nil)
        }
        
        @objc
        private func appDidBecomeActive() {
            // re-create sessionId if needed
            sessionUUID
        }
        @objc
        private func appDidEnterBackground() {
            _sessionUUID = nil
        }
    }
    
    

}
