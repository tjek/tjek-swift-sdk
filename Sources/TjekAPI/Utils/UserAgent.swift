///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// eg. "com.shopgun.ios.sdk/1.0.1 (com.myCompany.myApp/3.2.1) [iPad; iOS 11.5.2; Scale/2.00]"
internal func generateUserAgent() -> String {
    var userAgent = ""
    
    let appBundle = Bundle.main
    let sdkBundle = Bundle(for: TjekAPI.self)
    
    // append the app id/version
    if let appUA = appBundle.userAgent {
        userAgent += appUA
    }
    
    // add the sdk id/version
    if appBundle != sdkBundle, let sdkUA = sdkBundle.userAgent {
        if userAgent.isEmpty {
            userAgent += sdkUA
        } else {
            userAgent += " (\(sdkUA))"
        }
    }
    
    #if os(iOS)
    // append the device info if iOS
    userAgent += " [\(UIDevice.current.model); iOS \(UIDevice.current.systemVersion); Scale/\(String(format: "%0.2f", UIScreen.main.scale))]"
    #endif
    
    return userAgent
}

extension Bundle {
    /// "<bundle_id>/<short_version_string>" (eg. "com.myCompany.myApp/3.2.1")
    fileprivate var userAgent: String? {
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
