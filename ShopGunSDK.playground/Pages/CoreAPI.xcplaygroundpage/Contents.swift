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

func readCredentialsFile() -> (key: String, secret: String) {

    guard let fileURL = Bundle.main.url(forResource: "credentials.secret", withExtension: "json"),
        let jsonData = (try? String(contentsOf: fileURL, encoding: .utf8))?.data(using: .utf8),
        let credentialsDict = try? JSONDecoder().decode([String: String].self, from: jsonData),
        let key = credentialsDict["key"],
        let secret = credentialsDict["secret"]
        else {
        fatalError("""
Need valid `credentials.secret.json` file in Playground's `Resources` folder. eg: 
{
    "key": "your_key",
    "secret": "your_secret"
}

""")
    }
    return (key: key, secret: secret)
}


let creds = readCredentialsFile()

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

