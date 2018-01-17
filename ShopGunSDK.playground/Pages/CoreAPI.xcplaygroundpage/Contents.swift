import PlaygroundSupport
import Foundation
import ShopGunSDK // NOTE: you must build this targetting an iOS simulator

PlaygroundPage.current.needsIndefiniteExecution = true

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

let logHandler: ShopGunSDK.LogHandler = { (msg, lvl, source, location) in
    
    
    let output: String
    switch lvl {
    case .error:
        let filename = location.file.components(separatedBy: "/").last ?? location.file
        output = """
        ⁉️ \(msg)
           👉 \(location.function) @ \(filename):\(location.line)
        """
    case .important:
        output = "⚠️ \(msg)"
    case .verbose:
        output = "💬 \(msg)"
    case .debug:
        output = "🕸 \(msg)"
    }
    
    print(output)
}

///////////////////
// Dummy requests

extension CoreAPI.Requests {
    static func allDealers() -> CoreAPI.Request<[CoreAPI.Dealer]> {
        return .init(path: "/v2/dealers", method: .GET, timeoutInterval: 30)
    }
}

///////////////////

let creds = readCredentialsFile()

// must first configure
let coreAPISettings = CoreAPI.Settings(key: creds.key,
                                       secret: creds.secret,
                                       baseURL: URL(string: "https://api-edge.etilbudsavis.dk")!)

ShopGunSDK.configure(settings: .init(coreAPI: coreAPISettings, eventsTracker: nil, sharedKeychainGroupId: "blah"), logHandler: logHandler)

let token = ShopGunSDK.coreAPI.request(CoreAPI.Requests.getPagedPublication(withId: "6fe6Mg8")) { (result) in
    switch result {
    case .error(let error):
        ShopGunSDK.log("Failed: \(error)", level: .error, source: .other(name: "Example"))
    case .success(let publication):
        ShopGunSDK.log("Success!: \n \(publication)", level: .important, source: .other(name: "Example"))
        dump(publication)
    }
}
