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
        
        EventsTracker.trackId = "ABC123"
        EventsTracker.flushTimeout = 5
        EventsTracker.flushLimit = 3
//        ObjCTestClass.test()
        
        
        self.view?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.viewTapped(_:))))
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

//        EventsTracker.trackEvent("x-viewDidAppear", variables: ["foo":"bar"])
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func viewTapped(tap:UITapGestureRecognizer) {
//        EventsTracker.defaultTracker = EventsTracker(trackId:"sdfg")
//        EventsTracker.defaultTracker.viewContext = "SDfgsd"
//        EventsTracker.defaultTracker.trackEvent("x-ViewTapped")
        
        
        
//        EventsTracker.viewContext = "222"
//        
//        
//        let tracker = EventsTracker(trackId:"sdfg")
    }
}

