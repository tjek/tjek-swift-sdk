import Foundation
import ShopGunSDK

Logger.logHandler = playgroundLogHandler

// If you wish, configure the KeychainDataStore. If you dont it will be automatically configured as private when you configure a component that uses it.
//KeychainDataStore.configure(.sharedKeychain(groupId: "foo"))

CoreAPI.configure()
GraphAPI.configure()
EventsTracker.configure()

// If you try to re-configure the datastore you will get a warning, and it will no-op.
//KeychainDataStore.configure(.privateKeychain)

// If you try to access any of the components before they have been configured, there will be a fatalError
// print(EventsTracker.shared.settings)

// configure the EventsTracker. This will also use the shared keychain.
//EventsTracker.configure(.init(trackId: "trackId"))

print(CoreAPI.shared.settings)
print(GraphAPI.shared.settings)
print(EventsTracker.shared.settings)

print("✅")
