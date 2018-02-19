import PlaygroundSupport
import Foundation
import ShopGunSDK // NOTE: you must build this targetting an iOS simulator

PlaygroundPage.current.needsIndefiniteExecution = true

ShopGunSDK.configureForPlaygroundDevelopment()

let token = ShopGunSDK.coreAPI.request(CoreAPI.Requests.getPagedPublication(withId: "6fe6Mg8")) { (result) in
    switch result {
    case .error(let error):
        ShopGunSDK.log("Failed: \(error)", level: .error, source: .other(name: "Example"))
    case .success(let publication):
        ShopGunSDK.log("Success!: \n \(publication)", level: .important, source: .other(name: "Example"))
        dump(publication)
    }
}

