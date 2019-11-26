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

extension EventsTracker {
    
    /// Contains the logic for when we consider a session to have started (based on listening to the app's BecomeActive/EnterBackground notifications).
    class SessionLifecycleHandler {
        /// This callback is triggered when a new session starts (app becomes active after being in the background)
        var didStartNewSession: (() -> Void)?
        
        init() {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        deinit {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        
        fileprivate var isInBackground: Bool = false
        
        @objc
        fileprivate func appDidBecomeActive(_ notification: Notification) {
            if isInBackground {
                didStartNewSession?()
            }
            isInBackground = false
        }
        @objc
        fileprivate func appDidEnterBackground(_ notification: Notification) {
            isInBackground = true
        }
    }
}
