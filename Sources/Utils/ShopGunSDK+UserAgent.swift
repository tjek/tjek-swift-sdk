//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import UIKit

extension ShopGunSDK {
    
    // eg. "com.shopgun.ios.sdk/1.0.1 (com.shopgun.ios.myApp/3.2.1) [iPad; iOS 11.5.2; Scale/2.00]"
    internal static var userAgent: String {
        
        let sdkBundleId = "com.shopgun.ios.sdk"
        
        var userAgent = sdkBundleId
        
        // append the sdk version
        if let sdkVersion = Bundle(identifier: sdkBundleId)?.infoDictionary?["CFBundleShortVersionString"] as? String {
            userAgent += "/\(sdkVersion)"
        }
        
        // append the app id/version
        let appBundle = Bundle.main
        if let appBundleId = appBundle.bundleIdentifier {
            userAgent += " (\(appBundleId)"
            
            if let appVersion = appBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
                userAgent += "/\(appVersion)"
            }
            userAgent += ")"
        }
        
        // append the device info
        userAgent += " [\(UIDevice.current.model); iOS \(UIDevice.current.systemVersion); Scale/\(String(format: "%0.2f", UIScreen.main.scale))]"
        
        return userAgent
    }
}
