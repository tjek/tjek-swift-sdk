# ETA-SDK iOS Example

The example project in this folder will give you a few examples of how to use some aspects of the *eTilbudsavis iOS SDK*. 

These examples only cover a small set of what is possible with the SDK and the API, and it is recommended that you read both the README at the root of the SDK, and the API documentation ([http://engineering.etilbudsavis.dk/eta-api/](http://engineering.etilbudsavis.dk/eta-api/)).

In this README:

- [Installation](#installation)
- [Examples](#examples)
- [Digging Deeper](#digging-deeper)

## Installation

This example project uses **CocoaPods** to load the ETA-SDK - this is the recommended way of including the ETA-SDK in your project.

If you are new to CocoaPods, first take a quick trip to their site ([cocoapods.org](http://cocoapods.org)) and read the **Getting Started** guide before continuing.

To see how to add ETA-SDK to your project, look inside the `Podfile` in the root of this project.

Now, in the Terminal `cd` to the example project root and run `pod install` - this will download and setup the workspace with the latest versions of the ETA-SDK and all its dependancies.

**Note:** in order to build the app you must open the `.xcworkspace`, not the `.xcodeproj`.

### API Key & Secret

To begin using the SDK, you must obtain an API key. Visit [our developer page](http://etilbudsavis.dk/developers/) where you can create a user and an app.


## Examples

There are 2 main examples in the project. They are UIViewController subclasses that demonstate key functionality within the SDK:


### `ETA_ExampleViewController_Catalogs`

This shows how to make API calls to the SDK, and handle the JSON response. It presents a UITableView that is populated with a list of Catalog names and their thumbnails. It also shows some of the branding properties that are available for a Catalog object.

When you select a catalog it will send you to the next example view controller…


### `ETA_ExampleViewController_CatalogView`

Here you will see how to embed an interactive catalog into a view. When transitioning from the previous view controller it is given a catalog object. The UUID of this is passed to an `ETA_CatalogView` object that has been added as a subview. 

The ETA_CatalogView handles all the rendering, gestures and interaction - you can optionally register as a delegate to receive events from the ETA_CatalogView. For a list of the possible events see the `ETACatalogViewDelegate` protocol in `ETA_CatalogView.h`.



## Digging Deeper
Beyond these example controllers, you should also look in the `ETA_AppDelegate.m` to see how to initialize the SDK.

Of course, you should also look at the headers within the ETA-SDK itself. A good place to start is with `ETA.h`, `ETA_CatalogView.h`, and `ETA_ShoppingListManager.h`.

