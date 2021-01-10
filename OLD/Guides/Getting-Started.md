# 💡 Getting Started

This document is intended to provide an initial starting point for the `ShopGunSDK`. 

It will focus on the basics of adding a `PagedPublicationView` to your app (though there is much more you can do with the SDK if you dig deeper).

## ⚙️ Configuration

You must provide configuration settings for each of the components of the SDK that you are planning on using, before you use them.


The recommended way to configure the ShopGunSDK is by adding a `ShopGunSDK-Config.plist` file as a resource of the main bundle of your app.

Then, somewhere in your code (before you make any other calls to the SDK - so probably in your `AppDelegate`), you will need to call `configure()` on all the components you intend to use.

```swift
PagedPublicationView.configure()
```

> **Note:** If you make calls to `ShopGunSDK` components before they are configured, the SDK will trigger a **fatalError**.

In this example we are configuring the `PagedPublicationView`, which configures both the `CoreAPI` & `EventsTracker` components. For these components the following settings are required in your `ShopGunSDK-Config.plist` file:

- `CoreAPI`/`key`
- `CoreAPI`/`secret`
- `EventsTracker`/`appId`

You can get these values from the [ShopGun Developer](https://shopgun.com/developers) page.

For details of the required and optional settings you can add to the config file, and for how to manually configure the components, see the [Configuration](Configuration.md) guide.


## 📖 PagedPublicationView

The `PagedPublicationView` is a UIView subclass for showing and interacting with a catalog. It also manages all of the loading of the data from our `CoreAPI`.

> **Note:** You must configure the `CoreAPI` before using the PagedPublicationView, otherwise the SDK will trigger a fatalError.
> 
> If you wish to have usage stats collected you will also need to configure the EventsTracker.

### Adding to your view hierarchy

You can treat the `PagedPublicationView` like any other UIView, and add an instance as a subview of your UIViewController's view.

### Loading the contents

When you wish to start loading the publication into the view (most likely in the `viewDidLoad	` method of your UIViewController), call the following:

```swift
// pagedPublication is the PagedPublicationView instance.
pagedPublication.reload(publicationId: "<PUBLICATION_ID>")
```
> **Note:** You can get the *`<PUBLICATION_ID>`* from either a `CoreAPI` query that returns a list of publications, or from the [ShopGun website](https://shopgun.com/) (simply open a publication and look at the `Id` in the  URL eg. "shopgun.com/catalogs/**`abc123`**").

### Next steps

For more complex uses of the `PagedPublicationView`, including setting the pre-loaded state of the view, and showing a custom outro view, check the [PagedPublicationView](PagedPublicationView.md) guide.

If you wish to delve deeper into the SDK, you can read [API documentation](http://shopgun.github.io/shopgun-ios-sdk/).