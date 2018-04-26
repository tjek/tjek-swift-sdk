//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
extension EventsTracker {
    
    class SessionLifecycleHandler {
        var didStartNewSession: (() -> Void)?
        
        init() {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(_:)), name: .UIApplicationDidBecomeActive, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: nil)
        }
        deinit {
            NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
            NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
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
