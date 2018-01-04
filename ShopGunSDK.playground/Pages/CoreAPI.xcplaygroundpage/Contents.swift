import PlaygroundSupport
import Foundation
import ShopGunSDK

PlaygroundPage.current.needsIndefiniteExecution = true

///////////////////
// Dummy requests

extension CoreAPI.Requests {
    static func allDealers() -> CoreAPI.Request<[CoreAPI.Dealer]> {
        return .init(path: "/v2/dealers", method: .GET, timeoutInterval: 30)
    }
}

// MARK: -

var creds = (key: "key", secret: "secret")

// must first configure
let coreAPISettings = CoreAPI.Settings(key: creds.key,
                                       secret: creds.secret,
                                       baseURL: URL(string: "https://api-edge.etilbudsavis.dk")!,
                                       locale: "en_GB",
                                       appVersion: "LH TEST - IGNORE")

ShopGunSDK.logLevel = .verbose
ShopGunSDK.configure(settings: .init(coreAPI: coreAPISettings, eventsTracker: nil))

let token = ShopGunSDK.coreAPI.request(CoreAPI.Requests.allDealers()) { (result) in
    switch result {
    case let .error(error):
        print("Failed: \(error)")
    case let .success(dealers):
        print("Success!")
        dealers.forEach({ print($0) })
    }
}

//DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
//    token.cancel()
//}

