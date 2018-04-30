import PlaygroundSupport
import Foundation
import ShopGunSDK // NOTE: you must build this targetting an iOS simulator

PlaygroundPage.current.needsIndefiniteExecution = true

Logger.logHandler = playgroundLogHandler
CoreAPI.configure()

let token = CoreAPI.shared.request(CoreAPI.Requests.getPagedPublication(withId: "6fe6Mg8")) { (result) in
    switch result {
    case .error(let error):
        Logger.log("Failed: \(error)", level: .error, source: .other(name: "Example"))
    case .success(let publication):
        Logger.log("Success!: \n \(publication)", level: .important, source: .other(name: "Example"))
        dump(publication)
    }
}
