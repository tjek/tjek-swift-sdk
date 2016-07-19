//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation


struct Utils {

    static func fetchInfoPlistValue(key:String) -> AnyObject? {
        
        if let configDict = NSBundle.mainBundle().objectForInfoDictionaryKey("ShopGunSDK")?.copy() {
            
            return configDict[key]
        }
        return nil
    }
    
}