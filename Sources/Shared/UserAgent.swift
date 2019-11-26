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

// eg. "com.shopgun.ios.sdk/1.0.1 (com.shopgun.ios.myApp/3.2.1) [iPad; iOS 11.5.2; Scale/2.00]"
internal func userAgent() -> String {
    var userAgent = ""
    
    // add the sdk id/version
    let sdkBundle = Bundle(for: Logger.self)
    userAgent += sdkBundle.userAgent ?? ""
    
    // append the app id/version
    let appBundle = Bundle.main
    if let appUA = appBundle.userAgent {
        userAgent += " (\(appUA))"
    }

    // append the device info
    userAgent += " [\(UIDevice.current.model); iOS \(UIDevice.current.systemVersion); Scale/\(String(format: "%0.2f", UIScreen.main.scale))]"
    
    return userAgent
}

extension Bundle {
    var userAgent: String? {
        guard let bundleId = self.bundleIdentifier else {
            return nil
        }
        
        var userAgent = bundleId
        
        if let appVersion = self.infoDictionary?["CFBundleShortVersionString"] as? String {
            userAgent += "/\(appVersion)"
        }
        
        return userAgent
    }
}
