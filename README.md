ShopGunSDK
==========

[![Version](https://img.shields.io/cocoapods/v/ShopGunSDK.svg?style=flat)](http://cocoapods.org/pods/ShopGunSDK)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/ShopGunSDK.svg?style=flat)](http://cocoapods.org/pods/ShopGunSDK)
[![Platform](https://img.shields.io/cocoapods/p/ShopGunSDK.svg?style=flat)](http://cocoapods.org/pods/ShopGunSDK)

A framework for interacting with the ShopGun APIs from within your own apps. The SDK has been split into multiple components:

- `Core`: Used by all other components. Handles basic configuration of the SDK.
- `GraphKit`: An interface for easily making requests to ShopGun's graph API.
- `EventsKit`: An events tracker for efficiently sending events to the ShopGun API.
- `PagedPublication`: A view for fetching and rendering a paged publication.

## Requirements

- iOS 8.0+
- Xcode 8.0+
- Swift 3.0+


## Dependencies

- Core:
	- [Valet (2.2.2)](https://github.com/Square/Valet) - for easy communication with the KeyChain.


- PagedPublication:
	- [Verso (1.0)](https://github.com/ShopGun/Verso) - a layout engine for presenting book-like views.
	- [Kingfisher (3.0.1)](https://github.com/onevcat/Kingfisher) - a light-weight library for downloading and caching images.



## Installation

### Cocoapods
Add the following to your `Podfile` to include the entirety of the SDK to your project:

```ruby
use_frameworks!
pod 'ShopGunSDK'
```

If you only need a subset of the SDK's functionality, use one of the subspecs instead: 

```ruby
# just include the graph-related code:
pod 'ShopGunSDK/Graph'

# just include the event tracking code:
pod 'ShopGunSDK/Events'

# just include the paged publication view code:
pod 'ShopGunSDK/PagedPublication'
```

For further details see the [CocoaPods Guides](https://guides.cocoapods.org/).

> **Note**: For the legacy _eTilbudsavis SDK_, please use the old [`ETA-SDK`](http://cocoapods.org/pods/ETA-SDK) pod.

### Carthage

Point your `Cartfile` at the github repo:

```ruby
github 'shopgun/shopgun-ios-sdk'
```

Unlike CocoaPods, with Carthage you will not be able to choose which subsets of the functionality you include in your app - it's all or nothing.

For further details see the [Carthage Readme](https://guides.cocoapods.org/)

Furthermore, although the dependencies will be downloaded and built for you, you will need to manually embed the `.framework`s into your app.


## Usage

First you must import the SDK:

```swift
// Swift
import ShopGunSDK
```
```objc 
// Obj-C
@import ShopGunSDK;
```


### Configuration


```swift
// Swift
ShopGunSDK.SDKConfig.appId = "<myAppId>"
```
```objc
// Obj-C
SGNSDKConfig.appId = @"<myAppId>";
```


