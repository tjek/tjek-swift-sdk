# 💡 Getting Started

### Configuration

You must provide configuration settings for each of the components of the SDK that you are planning on using, before you use them.

If you have added the settings to a `ShopGunSDK-Configuration.plist` file that is included with your app, configuration is as simple as:

```swift
import ShopGunSDK
…
ShopGun.configure()
```
The best place to do this is probably somewhere in your AppDelegate, so that it is sure to be called before any other calls to the `ShopGunSDK` are made.

> **Note:** If you make calls to ShopGunSDK components before they are configured, the SDK will trigger a fatalError.

For more complex configuration options, including providing a custom log handler, check the [Configuration docs]()

### < TODO: MAKE SEPARATE CONFIGURATION DOCS >

### PagedPublicationView

The `PagedPublicationView` is a UIView subclass for showing and interacting with a catalog. It also manages all of the loading of the data from our `CoreAPI`.

> **Note:** You must configure the `CoreAPI` before using the PagedPublicationView, otherwise the SDK will trigger a fatalError.
> 
> If you wish to have usage stats collected you will also need to configure the EventsTracker.

Simply make an instance of `PagedPublicationView` and add it as a subview in your ViewController. Then, when you wish to start loading the catalog into the view (most likely in the `viewDidLoad	` method of your UIViewController), call the following:

```swift
self.pagedPublication.reload(publicationId: "<PUBLICATION_ID>")
```

For more complex uses of the `PagedPublicationView`, including setting the pre-loaded state of the view, and showing a custom outro view, check the [PagedPublication docs]()

### < TODO: MAKE SEPARATE PAGED PUB DOCS >

### CoreAPI

The `CoreAPI` component provides typesafe tools for working with the ShopGun API, and removes the need to consider any of the session and auth-related complexity when making requests.

> **Note:** You must provide a `key` and `secret` when configuring the ShopGunSDK, otherwise calls to the CoreAPI will trigger a fatalError. 
> 
> These can be requested by signing into the [ShopGun Developers](https://shopgun.com/developers) page.

The interface for making requests is very flexible, but a large number of pre-built requests have been included. For example:

```swift
// make a request object that will ask for a specific PagedPublication object
let req = CoreAPI.getPagedPublication(withId: …)

// Perform the request. The completion handler is passed a Result object containing the requested PagedPublication, or an error.
CoreAPI.shared.request(req) { (result) in
	switch result {
	case .success(let pagedPublication):
	   print("👍 '\(pagedPublication.id.rawValue)' loaded")
	case .error(let err):
	   print("😭 Load Failed: '\(err.localizedDescription)'")
}

```

For a more detailed explanation of the `CoreAPI`, check the [CoreAPI docs]()

### < TODO: MAKE SEPARATE COREAPI DOCS >

### EventsTracker

You should not have to use the EventsTracker directly. However, if using the PagedPublication it is recommended that you configure the EventsTracker so that usage stats can be collected from users of your app. 

For more details please read the [EventsTracker docs]()
### < TODO: MAKE SEPARATE EVENTSTRACKER DOCS >

### GraphAPI

Currently still a work in progress. Please come back later.

For more details please read the [GraphAPI docs]()
