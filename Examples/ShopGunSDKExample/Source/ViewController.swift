//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

import ShopGunSDK

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        EventsTracker.trackEvent("sdfg")
        
//        EventsTracker.sharedTracker?.trackEvent("sfdG")
//        EventsTracker.trackId = "ABC123"
//        EventsTracker.flushTimeout = 5
//        EventsTracker.flushLimit = 3
        EventsTracker.baseURL = NSURL(string: "https://events-staging.shopgun.com")!
        
//        ObjCTestClass.test()
        
        
        self.view?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.viewTapped(_:))))
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        EventsTracker.sharedTracker?.updateView(["home", "offers"])
        
        EventsTracker.sharedTracker?.trackEvent("x-viewDidAppear", properties: ["foo":"bar",
            "shit":NSDate(),
            "null":NSNull(),
            "arr":["a",1, 5.2],
            "dict":["b":15]
            ])
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func viewTapped(tap:UITapGestureRecognizer) {
//        EventsTracker.defaultTracker = EventsTracker(trackId:"sdfg")
//        EventsTracker.defaultTracker.viewContext = "SDfgsd"
//        EventsTracker.defaultTracker.trackEvent("x-ViewTapped")
        print("clientId:",SDKConfig.clientId)
        
        EventsTracker.sharedTracker?.trackEvent("x-viewTapped")
//        EventsTracker.viewContext = "222"
//        
//        
//        let tracker = EventsTracker(trackId:"sdfg")
    }
}

