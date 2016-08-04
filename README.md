ShopGunSDK
==========

[![Platform](https://cocoapod-badges.herokuapp.com/p/ShopGunSDK/badge.png)](http://cocoadocs.org/docsets/ShopGunSDK)
[![Version](https://cocoapod-badges.herokuapp.com/v/ShopGunSDK/badge.png)](http://cocoadocs.org/docsets/ShopGunSDK) 
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)


A framework for interacting with the ShopGun APIs from within your own apps.

Functionality includes:

- `GraphKit`: An interface for easily making requests to ShopGun's graph API.
- `EventsKit`: An events tracker for efficiently sending events to the ShopGun API.



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
```

For further details see the [CocoaPods Guides](https://guides.cocoapods.org/).

> **Note**: For the legacy _eTilbudsavis SDK_, please use the old [`ETA-SDK`](http://cocoapods.org/pods/ETA-SDK) pod.

### Carthage

Point your `Cartfile` at the github repo:

```ruby
github 'shopgun/shopgun-ios-sdk'
```

Unlike CocoaPods, with Carthage you will not be able to choose which subsets of the functionality you include in your app - it's all or nothing.

For further details see the [Carhage Readme](https://guides.cocoapods.org/)

Furthermore, you will need to manually embed the `Valet.framework` into your app.

**TODO: Write how to do this**


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


