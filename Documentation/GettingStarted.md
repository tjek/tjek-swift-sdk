# Getting Started

The steps to get started are as follows:

1. Install CocoaPods - See [cocoapods.org](http://cocoapods.org).
2. [Update your Podfile](#update-your-podfile)
3. [Request an API Key & Secret](#api-key-and-secret)
4. [Configure the SDK in your project](#configure-the-sdk)

Further reading:

- [Making API Requests](APIRequests.md)
- [Catalog Reader](CatalogReader.md)
- [List Manager](ListManager.md)




## Update your Podfile

The SDK is split into multiple components (subspecs), allowing you to choose which aspects of the SDK to include in your project.

The following components are available:

- `API` - The basis for making all requests to the ETA server. This is automatically included if you use any of the other components.
- `CatalogReader` - A native catalog reading experience
- `ListManager` - The means of creating your own shopping lists.


You specify the component to install in your **Podfile**. For example, to install the CatalogReader, add the following:

	pod 'ETA-SDK/CatalogReader'

    
You then simply run `pod install` in your project directory - this will add the relevant ETA-SDK files to your project, and manage all the dependencies.


*See the documentation on the [CocoaPods website](http://cocoapods.org) if you are new to them.*


## API Key and Secret

To begin using the SDK, you must obtain an API key and Secret.

Visit [our developer page](http://etilbudsavis.dk/developers/) where you can create a user and an app.

## Configure the SDK

Before your make any requests or use any component, you must initialise the SDK with your API key & secret, and your app's version (this can be found with the `CFBundleVersion` key).

In your `AppDelegate.h` file:

```objective-c
// Import the ETA-SDK header file
#import <ETA-SDK/ETA.h>

...

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	...
	// Initialize the SDK with your API Key, Secret & app version
	[ETA initializeSDKWithAPIKey:@"your-api-key" apiSecret:@"your-api-secret" appVersion:@"your.app.version"];
	...
	
}
```

Then, whenever you want to talk to the SDK, use the singleton object `ETA.SDK`. This will return the object initialized with the key/secret in the above call. You will just get `nil` if you ask for the singleton before initializing it.


See the [ETA-SDK Example project](../ETA-SDK Example) for an example.

