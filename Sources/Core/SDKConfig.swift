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
            if let cachedClientId = Utils.getKeychainString("ClientId") {
                _clientId = cachedClientId
            }
            else {
                _clientId = UUID().uuidString
                
                _ = Utils.setKeychainString(_clientId!, key: "ClientId")
            }
        }
        return _clientId!
    }
    
    public static func resetClientId() {
        _ = Utils.removeKeychainObject("ClientId")
        _clientId = nil
    }
    
    
    
    // sessionId exists only while the app is in an active state, and reset when the app goes into the background.
    public static var sessionId : String {
        return _sessionHandler.sessionUUID
    }
    
    
    
    
    
    // MARK: Private
    
    fileprivate static var _overrideAppId : String? = nil
    fileprivate static let _globalAppId : String? = {
        return Utils.fetchInfoPlistValue("AppId") as? String
    }()
    
    fileprivate static var _clientId : String?

    fileprivate static let _sessionHandler:SessionLifecycleHandler = SessionLifecycleHandler()
    fileprivate class SessionLifecycleHandler {
        
        /// sessionUUID is lazily generated if nil
        fileprivate var _sessionUUID:String?
        var sessionUUID:String {
            if _sessionUUID == nil {
                _sessionUUID = UUID().uuidString
            }
            return _sessionUUID!
        }
        
        init() {
            // force a re-creation of the sessionUUID
            _ = sessionUUID
            
            NotificationCenter.default.addObserver(self, selector:#selector(SessionLifecycleHandler.appDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
            NotificationCenter.default.addObserver(self, selector:#selector(SessionLifecycleHandler.appDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)


        }
        deinit {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        }
        
        @objc
        fileprivate func appDidBecomeActive() {
            // re-create sessionId if needed
            _ = sessionUUID
        }
        @objc
        fileprivate func appDidEnterBackground() {
            _sessionUUID = nil
        }
    }
}
