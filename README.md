# ShopGunSDK

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

For further details see the [CocoaPods Guides](https://guides.cocoapods.org/)


### Carthage

Point your `Cartfile` at the github repo:

```ruby
github 'shopgun/shopgun-ios-sdk'
```

Unlike CocoaPods, with Carthage you will not be able to choose which subsets of the functionality you include in your app - it's all or nothing.

For further details see the [Carhage Readme](https://guides.cocoapods.org/)


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

