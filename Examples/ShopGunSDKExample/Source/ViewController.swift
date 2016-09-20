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
    
    let conn = GraphConnection(baseURL:URL(string: "https://graph-staging.shopgun.com")!, timeout:10)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ObjCTestClass.config()
        ObjCTestClass.eventsTracker()
        ObjCTestClass.graphRequest()

        
        let dblTap = UITapGestureRecognizer(target: self, action: #selector(ViewController.viewDblTapped(_:)))
        dblTap.numberOfTapsRequired = 2
        self.view?.addGestureRecognizer(dblTap)
        
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.viewTapped(_:)))
        tap.require(toFail: dblTap)
        self.view?.addGestureRecognizer(tap)
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func viewDblTapped(_ tap:UITapGestureRecognizer) {
        
    }
    func viewTapped(_ tap:UITapGestureRecognizer) {
        
    }
}

