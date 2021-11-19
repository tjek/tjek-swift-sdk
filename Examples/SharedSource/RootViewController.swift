///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import UIKit
import TjekSDK

class RootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initializeTjekSDK()
        
        // show the publication list
        let contents = UINavigationController(rootViewController: PublicationListViewController())
        self.cycleFromViewController(oldViewController: nil, toViewController: contents)
    }
}

func initializeTjekSDK() {
    
    // update the logger to print all logs.
//    TjekSDK.logger.handler = .consolePrinter()
    
    do {
        // Initialize the TjekSDK using the `TjekSDK-Config.plist` file.
        try TjekSDK.initialize()
        
        // Alternatively, initialize the TjekSDK manually
//        TjekSDK.initialize(
//            config: try .init(
//                apiKey: "<your api key>",
//                apiSecret: "<your api secret>",
//                trackId: .init(rawValue: "<your track id>")
//            )
//        )
        
    } catch {
        print("❌ Unable to initialize TjekSDK", error.localizedDescription)
    }
}
