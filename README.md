ShopGunSDK
==========

[![Version](https://img.shields.io/cocoapods/v/ShopGunSDK.svg?style=flat)](http://cocoapods.org/pods/ShopGunSDK)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.md)
[![Swift](http://img.shields.io/badge/swift-4.0-brightgreen.svg)](https://swift.org)

A framework for interacting with the ShopGun APIs from within your own apps. The SDK has been split into several components:

- `PagedPublicationView`: A view for fetching, rendering, and interacting with, a catalog.
- `CoreAPI`: Simplifies auth & communication with the ShopGun REST API.
- `GraphAPI`: An interface for easily making requests to ShopGun's GraphQL API.
- `EventsTracker`: An events tracker for efficiently sending events to the ShopGun API.

## Requirements

- iOS 9.3+
- Xcode 9.0+
- Swift 4.0+


## Installation

#### Dependencies

- [Valet](https://github.com/Square/Valet) - for easy communication with the KeyChain.
- [Verso](https://github.com/ShopGun/Verso) - a layout engine for presenting book-like views.
- [Kingfisher](https://github.com/onevcat/Kingfisher) - A lightweight, pure-Swift library for downloading and caching images from the web.
- [xctoolchain](https://github.com/parse-community/xctoolchain-archive) - Common configuration files and scripts.


### CocoaPods

### Carthage

### Manually


## Usage

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

```swift
let config = ShopGun.Settings(coreAPI: CoreAPI.Settings(key: "<API_KEY>", 
                                                     secret: "<API_SECRET>"), 
                        eventsTracker: EventsTracker.Settings(trackId: "<TRACK_ID>"), 
                             graphAPI: nil, 
                sharedKeychainGroupId: "com.mycompany.shared-keychain")

ShopGun.configure(config)
```

### PagedPublicationView

The `PagedPublicationView` is a UIView subclass for showing and interacting with a catalog. It also manages all of the loading of the data from our `CoreAPI`.

> **Note:** You must provide `CoreAPI` settings when configuring the SDK, otherwise the SDK will trigger a fatalError. 
> 
> If you wish to have usage stats collected you will also need to provide EventsTracker settings when configuring the SDK.

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
ShopGun.coreAPI.request(req) { (result) in
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
