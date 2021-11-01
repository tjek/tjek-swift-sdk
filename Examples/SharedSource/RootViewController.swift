//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import UIKit
//import ShopGunSDK
import TjekSDK

class RootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initializeTjekSDK()
        
//        configureShopGunSDK()
        
        // show the publication list
        let contents = UINavigationController(rootViewController: PublicationListViewController())
        self.cycleFromViewController(oldViewController: nil, toViewController: contents)
    }
}

func initializeTjekSDK() {
    // Initialize the TjekSDK using the `TjekSDK-Config.plist` file.
    do {
        try TjekSDK.initialize()
    } catch {
        print("❌ Unable to initialize TjekSDK", error.localizedDescription)
    }
    
    // You can instead initialize the TjekAPI programatically, if you need to.
//    TjekAPI.initialize(config: .init(apiKey: "<your api key>", apiSecret: "<your api secret>"))
}

//func configureShopGunSDK() {
//
//    // By default the ShopGunSDK will print critical logs.
//    // You can override what/how they things are logged by replacing the logHandler.
//    Logger.logHandler = verboseLogHandler
//
//    // Configure the ShopGunSDK, using the ShopGunSDK-Config.plist file.
//    // If the config file is not setup correctly these will trigger a fatalError.
//
//    // 👉 In order to try the demo, please fill in the `ShopGunSDK-Config.plist` with, at the very least, the following information (found at https://shopgun.com/developers/apps ):
//    // - CoreAPI.key
//    // - CoreAPI.secret
//    // - GraphAPI.key (same as CoreAPI.key)
//
//    // Configuring the CoreAPI allows for requests to be made to the ShopGun CoreAPI (showing paged publications, or accessing CoreAPI requests)
//    CoreAPI.configure()
//
//    // Configuring the EventsTracker allows for anonymous usage data to be sent when viewing paged or incito publications.
//    EventsTracker.configure()
//
//    // Configuring the Graph allows for graph requests to be made (when showing Incito Publications)
//    GraphAPI.configure()
//
//}
//
//let verboseLogHandler: Logger.LogHandler = { (message, level, source, location) in
//
//    let output: String
//    switch level {
//    case .error:
//        output = """
//        ⁉️ \(message)
//        👉 \(location.functionName) @ \(location.fileName):\(location.lineNumber)
//        """
//    case .important:
//        output = "⚠️ \(message)"
//    case .verbose:
//        output = "🙊 \(message)"
//    case .debug:
//        output = "🔎 \(message)"
//    case .performance:
//        output = "⏱ \(message)"
//    }
//
//    print(output)
//}
