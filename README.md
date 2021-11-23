TjekSDK
==========

[![Build Status](https://github.com/shopgun/shopgun-ios-sdk/actions/workflows/main.yml/badge.svg)](https://github.com/shopgun/shopgun-ios-sdk/actions/workflows/main.yml)
[![Version](https://img.shields.io/cocoapods/v/ShopGunSDK.svg?style=flat)](http://cocoapods.org/pods/ShopGunSDK)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.md)
[![Swift](http://img.shields.io/badge/swift-5.0-brightgreen.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-supported-DE5C43.svg?style=flat)](https://swift.org/package-manager/)

## Introduction

This is an SDK for interacting with the different Tjek services from within your own apps. The SDK has been split into several libraries, which can be loaded independently if you wish:

- **`TjekCatalogViewer`**: Includes several UIViewControllers for fetching, rendering, and interacting with, digital catalogs. These can be in `PDF` or [`Incito`](https://tjek.com/incito/) formats.
- **`TjekAPI`**: Makes sending requests to our API simple and type-safe. Contains all the model objects, and a number of specific requests, needed for interacting with our API. 

For your convenience, these libraries are wrapped by the **`TjekSDK`** library. This is a simple wrapper around all the other libraries, allowing you to easily import and initialize them all.

## Compatibility
| Environment | Details     |
| ----------- |-------------|
| 📱 iOS      | 12.0+      |
| 🛠 Xcode    | 12.0+       |
| 🐦 Language | Swift 5.0  |

## Installation

TjekSDK supports the following dependency managers. Choose your preferred method to see the instructions:

<details><summary>**Swift Package Manager**</summary>

TjekSDK can be built for all Apple platforms using the Swift Package Manager.

Add the following entry to your `Package.swift`:

```swift
.package(url: "https://github.com/shopgun/shopgun-ios-sdk.git", .upToNextMajor(from: "5.0.0"))
```
</details>

<details><summary>**CocoaPods**</summary>

TjekSDK can only be built for iOS using CocoaPods. For other platforms, please use Swift Package Manager.

Add the following entry in your `Podfile`:

```ruby
pod 'TjekSDK', '5.0.0'
```

You can also choose to only install the API subspec, if you dont need the CatalogViewer:

```ruby
pod 'TjekSDK/API', '5.0.0'
```

</details>

## Getting Started

In order to use our SDK you will need to sign up for a free [developer account](https://etilbudsavis.dk/developers). 

This will give you an `API key`, `API secret`, and a `Track ID`. The SDK must be initialized with these 3 values in order to work.

### Initialization via Config file 

The easiest way to initialize the SDK is to simply save these 3 keys in a config file.

The file is called `TjekSDK-Config.plist`, and must be copied into your app's main bundle. 

> You can see an example of this file in the Examples project (located at `./Examples/SharedSource/TjekSDK-Config.plist`)

Then, when your app starts, you just need to import the SDK and call `initialize`: 

```swift
import TjekSDK

do {
    // Initialize the TjekSDK using the `TjekSDK-Config.plist` file.
    try TjekSDK.initialize()
} catch {
    print("❌ Unable to initialize TjekSDK", error.localizedDescription)
}
```

### Initialize manually

If you would rather initialize the SDK programmatically, you can do so in code instead:

```swift
import TjekSDK

do {
    // Initialize the TjekSDK manually
    TjekSDK.initialize(
        config: try .init(
            apiKey: "<your api key>",
            apiSecret: "<your api secret>",
            trackId: .init(rawValue: "<your track id>")
        )
    )
} catch {
    print("❌ Unable to initialize TjekSDK", error.localizedDescription)
}
```

## Examples

Open `TjekSDK.xcworkspace` to build and explore the different demo projects.

> There is a demo for each dependency manager type (`SPMDemo` & `CocoapodsDemo`). Check their individual `Readme` files for more details.

## Usage

### CatalogViewer

There are two different ways of showing catalogs - as an [`Incito`](https://tjek.com/incito/) (vertically scrolling dynamic content) or as a PDF (horizontally paged static images). 

You choose which one to use based on the `hasIncitoPublication` and `hasPagedPublication` properties on the `Publication_v2` model - you can fetch this model using one of the publication requests in `TjekAPI/CommonRequests.swift`.

#### Incito Viewer

In order to show an Incito catalog, you subclass `IncitoLoaderViewController` and call one of the `super.load()` functions. See `Examples/SharedSource/DemoIncitoPublicationViewController.swift` for more details.

#### PDF Viewer

To show a PDF catalog, add an instance of `PagedPublicationView` to your view controller, and then call `reload()` on this view. See `Examples/SharedSource/DemoPagedPublicationViewController.swift` for more details.

### TjekAPI

Once initialized (using `TjekSDK.initialize`, or `TjekAPI.initialize`), you will be able to use `TjekSDK.api` to access an instance of the `TjekAPI` class. 

> Note: you can also use `TjekAPI.shared` if you are only importing the TjekAPI library - `TjekSDK.api` is simply a reference to the `TjekAPI.shared` singleton.

It is via this `TjekAPI` class that you send `APIRequests` to our server.

An `APIRequest` is a struct that contains all the knowledge about how and where to send a server request, and how to parse the input and output data. We provide implementations of a number of our api requests.

> The common pattern is to use a static function on the APIRequest type to generate the request object. You can also build APIRequests yourself, though this shouldnt be necessary.

Once you have a request object, you 'send' it to the API.

```swift
let request: APIRequest = .getPublication(withId: "<publication id>")
TjekSDK.api.send(request) { result in
	switch result {
	case let .success(publication):
		// `publication` is a concrete Publication type, as defined in the APIRequest
	case let .failure(error):
		// `error` is of type APIError
	}
}
```

The `send` function takes an APIRequest, and has a completion handler that is called (on `main` queue by default). Once completed you recieve a result `Result<ResponseType, APIError>` which contains either the success type (defined by the APIRequest) or an `APIError`.

> We also provide an implementation of `send` that returns a `Future` - a promise of work to be done, which can be run at a later date. Details about using these Future types can be found [here](https://github.com/shopgun/swift-future).

## Changelog
For a history of changes to the SDK, see the [CHANGES](CHANGES.md) file. 

> This also includes migration steps, where necessary.

## License
The `TjekSDK` is released under the MIT license. See [LICENSE](LICENSE.md) for details.
