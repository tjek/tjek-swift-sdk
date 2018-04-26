# 💾 Installation 

This guide provides details on how to install the `ShopGunSDK` framework.

## Requirements

- iOS 9.3+
- Xcode 9.0+
- Swift 4.0+

## Dependencies

The ShopGunSDK relies on several 3rd party frameworks to perform some of its tasks.

| Dependency | |
| :--- | :--- |
| [Kingfisher](https://github.com/onevcat/Kingfisher) | A lightweight, pure-Swift library for downloading and caching images from the web. |
| [Valet](https://github.com/Square/Valet) | For easy communication with the KeyChain. |
| [Verso](https://github.com/ShopGun/Verso) | A layout engine for presenting book-like views. |
| [xctoolchain](https://github.com/parse-community/xctoolchain-archive) | Common configuration files and scripts. |

## CocoaPods

The preferred way to install `ShopGunSDK` is using [CocoaPods](https://cocoapods.org/).

In order to use the latest release of the framework, add the following to your `Podfile`:

```ruby
pod 'ShopGunSDK'
```

This will install all the SDK's components.

### Subspecs

Each of the SDK components are separately installable when using CocoaPods, so you can use **subspecs** to choose which components you require.

For example, to install only the `PagedPublicationView` component, add the following to your `Podfile`:
 
```ruby
pod 'ShopGunSDK/PagedPublicationView'
```

> Note: Some of the components depend upon each other, so you may find some other components installed implicitly).


No matter if you are installing separate components, or the entire SDK, importing code in Swift is the same:

```swift
import ShopGunSDK
```
