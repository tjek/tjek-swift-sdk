ShopGunSDK
==========

[![Build Status](https://img.shields.io/travis/shopgun/shopgun-ios-sdk.svg)](https://travis-ci.com/shopgun/shopgun-ios-sdk)
[![Version](https://img.shields.io/cocoapods/v/ShopGunSDK.svg?style=flat)](http://cocoapods.org/pods/ShopGunSDK)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.md)
[![Swift](http://img.shields.io/badge/swift-4.1-brightgreen.svg)](https://swift.org)

## Introduction

This is a framework for interacting with the ShopGun APIs from within your own apps. The SDK has been split into several components:

| Component | Description |
| :--- | :--- |
| 📖 **`PagedPublicationView`** | A view for fetching, rendering, and interacting with, a catalog. |
| 🤝 **`CoreAPI`** | Simplifies auth & communication with the ShopGun REST API. |
| 🔗 **`GraphAPI`** | An interface for easily making requests to ShopGun's GraphQL API. |
| 📡 **`EventsTracker`** | An events tracker for efficiently sending analytics events. |


## Guides

#### 💾 [Installation](Guides/Installation.md) 

#### 💡[Getting Started](Guides/Getting-Started.md)

#### 📚 [API Documentation](http://shopgun.github.io/shopgun-ios-sdk/) 

### Detailed Guides
- [Configuration](Guides/Configuration.md)
- [PagedPublicationView](Guides/PagedPublicationView.md)
- [CoreAPI](Guides/CoreAPI.md)
- [GraphAPI](Guides/GraphAPI.md)
- [EventsTracker](Guides/EventsTracker.md)
- [Logging](Guides/Logging.md)

## Quick Start

### Requirements

- iOS 9.3+
- Xcode 9.0+
- Swift 4.0+

### Installation

The preferred way to install the `ShopGunSDK` framework into your own app is using [CocoaPods](https://cocoapods.org/). Add the following to your `Podfile`:

```ruby
pod 'ShopGunSDK'
```

For more detailed instructions, see the [Installation](Guides/Installation.md) guide.

### Examples

The repo uses a swift playground to demonstrate example uses of the components. 

- Download/checkout this repo.
- Make sure you recursively checkout all the submodules in the `External` folder.
- Open the `ShopGunSDK.xcodeproj`, and build the ShopGunSDK scheme (using a simulator destination)
- Open the `ShopGunSDK.playground` that is referenced inside the project. From here, you will be able experiment with the SDK.

> **Note:** In order to use the components properly they must be configured with the correct API keys. Set the values in the playground's `Resources/ShopGunSDK-Config.plist` file with your own API keys (accessible from the [ShopGun Developer page](https://shopgun.com/developers))
> 
> **Also Note:** Xcode Playgrounds can be a bit flaky when it comes to importing external frameworks. If it complains, try cleaning the build folder and rebuilding the SDK (targetting a simulator), and if it continues, restart Xcode. Also sometimes commenting out contents of the `playgroundLogHandler.swift` file, and then uncommenting again, helps.

For a more detailed guide, see the [Getting Started](Guides/Getting-Started.md) guide.


## Changelog
For a history of changes to the SDK, see the [CHANGES](CHANGES.md) file.

## License
The `ShopGunSDK` is released under the MIT license. See [LICENSE](LICENSE.md) for details.