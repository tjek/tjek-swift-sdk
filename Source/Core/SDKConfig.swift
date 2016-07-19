//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation


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
    
    public static var clientId : String {
        return ""
    }
    
    public static var sessionId : String {
        return ""
    }
    
    
    public static func test(arr:[String]?) {
    
    }
    
    
    // MARK: Private
    
    private static var _overrideAppId : String? = nil
    private static let _globalAppId : String? = {
        return Utils.fetchInfoPlistValue("AppId") as? String
    }()
}
