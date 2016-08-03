//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation
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
    
    
    private static let keychainValet:VALValet? = VALValet(identifier: "com.shopgun.ios.sdk.keychain", accessibility: .AfterFirstUnlock)
    
    private static var _clientId : String?
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
    
    
    
    private static var _sessionId : String?
    public static var sessionId : String {
        if _sessionId == nil {
            if let cachedSessionId = keychainValet?.stringForKey("SessionId") {
                _sessionId = cachedSessionId
            }
            else {
                _sessionId = NSUUID().UUIDString
                keychainValet?.setString(_sessionId!, forKey: "SessionId")
            }
        }
        return _sessionId!
    }

    
    
    
    
    // MARK: Private
    
    private static var _overrideAppId : String? = nil
    private static let _globalAppId : String? = {
        return Utils.fetchInfoPlistValue("AppId") as? String
    }()
}
