import Foundation
import ShopGunSDK // NOTE: you must build this targetting an iOS simulator

Logger.logHandler = playgroundLogHandler

// Using the default `configure` methods will use values in the `ShopGunSDK-Config.plist` to setup each component
CoreAPI.configure()
GraphAPI.configure()
EventsTracker.configure()

// Once you have configured the components you can access their `.shared` instances without triggering a fatalError
print(CoreAPI.shared.settings)
print(GraphAPI.shared.settings)
print(EventsTracker.shared.settings)

print("✅")
