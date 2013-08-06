#	eTilbudsavis iOS SDK

The ETA-SDK makes it easy to communicate with the eTilbudsavis API. The SDK handles all the concurrent networking issues and session management, so that you can focus on presenting the data.

In this README:

- Installation
  - [CocoaPods](#cocoapods)
  - [Manual Installation](#manual-installation)
  - [API Key and Secret](#api-key-and-secret)
- Usage
  - [ETA SDK](#eta-sdk)
  - [Shopping List Manager](#shopping-list-manager)
  - [Catalog View](#catalog-view)


# Installation

## CocoaPods
The easiest way to install the eTilbudsavis SDK is using [CocoaPods](http://cocoapods.org).

Simply add the `ETA-SDK` pod to your Podfile:

    pod 'ETA-SDK'
    
Then run `pod install` in your project directory - this will add the ETA SDK to your project, and manage all the dependencies.

See the documentation on the CocoaPods website if you are new to them.


## Manual Installation

#### 1. Download SDK
If for some reason you dont want to use CocoaPods (you really should, they're great), you can download the SDK and the associated examples from [GitHub](https://github.com/eTilbudsavis/native-ios-eta-sdk/).

#### 2. Add to project
You then need to add the ETA-SDK folder into your project, making sure that the "*Copy items into destination group’s folder (if needed)*" checkbox is checked".

Now, in your project's **Build Phases**, under the **Link Binary With Libraries** phase, add `CoreLocation.framework`.

Note that the ETA-SDK uses ARC.

 
#### 3. Install third-party libraries

ETA-SDK has a number of dependencies with third-party libraries (all use the MIT license). You must follow the installation instructions for each library:

- [AFNetworking](https://github.com/AFNetworking/AFNetworking) - Handles all the networking requests.
- [Mantle](https://github.com/github/Mantle) - Super-class to all the model objects. Allows for easy conversion to/from a JSON dictionary.
- [FMDB](https://github.com/ccgus/fmdb) - Handles all the SQLite database communication.


## API Key and Secret

To begin using the SDK, you must obtain an API key. Visit [our developer page](http://etilbudsavis.dk/developers/) where you can create a user and an app.

See the **[Initialization](#initialization)** section below for how to use the key and secret.

&nbsp;
&nbsp;

---

# Usage
There are 3 components to the ETA SDK, `ETA`, `ETA_ShoppingListManager` and `ETA_CatalogView`. 

The `ETA_ShoppingListManager` and `ETA_CatalogView` both make use of the `ETA` object, but are independant of each other.

## ETA SDK
> \#import "ETA.h"

The `ETA` class is the main interface into the eTilbudsavis SDK. It handles all the boring session management stuff, freeing you to simply make API requests.

### Initialization

The easiest way to use the ETA is with the singleton methods. 

First, in your `application:didFinishLaunchingWithOptions:` method add the line:

    [ETA initializeSDKWithAPIKey:@"your-api-key" apiSecret:@"your-api-secret"];

Then, to get the singleton object, simply call `ETA.SDK`. This will return the object initialized with the key/secret in the above call. You will just get *nil* if you ask for the singleton before initializing it.

If, in the very rare case, you want multiple instances of the ETA class you can use `+etaWithAPIKey:apiSecret:`. But I don't know why you would want to.

### API Calls

Documentation of the possible API calls can be found at [http://engineering.etilbudsavis.dk/eta-api/](http://engineering.etilbudsavis.dk/eta-api/).

In order to make API requests you use the following method on an `ETA` instance:

    - (void) api:(NSString*)requestPath 
            type:(ETARequestType)type 
      parameters:(NSDictionary*)parameters 
        useCache:(BOOL)useCache 
      completion:(void (^)(id response, NSError* error, BOOL fromCache))completionHandler;

- `requestPath` is a string containing the API request (optionally including "?key1=val1,key2=val2" style parameters)
- `type` describes how you want to send the request to the server: `GET`, `POST`, `PUT`, or `DELETE`
- `parameters` is an optional dictionary to be sent with the request. It will be merged with and override any "?key1=val1,key2=val2" parameters included in the `requestPath`. When using `GET` these will usually be filter or sort queries, while with `PUSH` it can be a JSON dictionary of a model object.
- `useCache` lets you choose whether to quickly try to first get results from the SDK's cache. See the **[Caching](#caching)** section below for more details.
- `completionHandler` is a callback that is called when the API request finishes (and possibly also when a result is found in the cache). It is called on the main queue. It provides the following values:
	- `response` is the JSON response from the server. It has been pre-parsed, and so can be in the form of an `NSArray`, `NSDictionary`, `NSNumber` or `NSString`. If something went wrong it will be `nil`.
	- `error` contains a description of the problem, if something went wrong. Otherwise it is `nil`.
	- `fromCache` shows whether or not the response came from the cache (as described in the **[Caching](#caching)** section below).


For example, to get an array of catalogs for some specific dealers, sorted by distance and then name, use the following call:

    [ETA.SDK api: @"/v2/catalogs"
            type: ETARequestTypeGET
      parameters: @{ @"dealer_ids": @[@"d432U", @"1f30I"],
                     @"order_by":@[@"distance", @"name"] }
      completion:^(id response, NSError *error, BOOL fromCache) {
          NSLog(@"JSON Response: %@", response);
      }];
*Note that this is using a variant of the `-api:…` method where `usesCache` is YES by default.*


##### Caching
Every time an API call returns a valid object (when `useCache` is true), the JSON dictionary is saved to the cache, keyed on the object's `ern`. The next time an API call is made that is asking for a specific object or list of objects, the SDK looks in the cache for previous results matching the requested object. 

It will always still send the request to the server, but if it does find matching objects in the cache the `completionHandler` will be called twice, the `fromCache` property specifying whether the response came from the cache or not (the response will be a copy of the cache data). If you are asking for a list of objects, and not all of the objects are in the cache, it will be as if none of the objects are in the cache. 

Objects have a limited cache lifespan, and will not be returned if out of date (lifespan depends on the object type, but defaults to around 15mins). The cache will be cleaned of out-of-date objects at a regular interval, and whenever you request an object that is out-of-date. 

You can manually clear all objects from the cache by calling `-clearCache`, or just out of date objects with `-clearOutOfDateCache`. Note that clearing out of date objects iterates the entire cache, so should not be done regularly - you probably only want to do this if you get a low memory warning, in which case you should just clear the entire cache.


##### Endpoints
An Endpoint represents a component of an API request that results in a response. There is a utility class called `ETA_API` that provides a lot of useful information and shortcuts for the possible endpoints.

Mostly you will be using it to generate API request paths. For example, a more future proof method of generating the @"/v2/catalogs" request path string we used above would be as follows:

    // @"/v2/catalogs"
    NSString* requestPath = [ETA_API path:ETA_API.catalogs];

You can also chain endpoints as follows:

    // @"/v2/offers/123abc/stores"
    NSString* requestPath = [ETA_API pathWithComponents:@[ ETA_API.offers,
                                                           @"123abc",
                                                           ETA_API.stores ]];
    

### Connecting
Before any API requests can be sent, the SDK must create a session. This is all done automatically the first time you send an API request, and all API requests you send will wait until the session is created. It will, however, mean that your first API call may slower than normal.

If you want to manually connect before you make any API calls, you can use the following method:

    - (void) connect:(void (^)(NSError* error))completionHandler;

The `completionHandler` will be called (on the main queue) when the session is connected, and if it failed to connect `error` will be non-nil. Any future calls to `-connect:` will call the completionHandler instantly. If you make any API calls before the completionHandler is triggered they will just wait to be sent until the connect finishes.



### User login

Certain funtionality, such as shopping lists, behave differently when a user is logged in. You log a user in by attaching their userID to the current active session. All future API calls will then be in relation to that user.

Attach a user with the following method:

    - (void) attachUserEmail:(NSString*)email 
                    password:(NSString*)password 
                  completion:(void (^)(NSError* error))completionHandler;
Where `email` is the email the user created their account with, and `password` is their password in plain text. When login finishes (successfully or not), the `completionHandler` is called on the main queue. If there was anything wrong with the login the `error` will provide information.

Once logged in you can access the user's information with the `attachedUser` property of the `ETA` instance. Note that this user is simply a copy of the current state, and changing it's properties will have no bearing on the attached user. You must always make API calls to affect state chages.

To logout, simply call `-detachUserWithCompletion:`.

##### User Change Notification
You can also listen for changes to the attached user in the `NSNotificationCenter`, by listening for the name `ETA_AttachedUserChangedNotification`. For example:

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(userChanged:)
                                               name:ETA_AttachedUserChangedNotification
                                             object:ETA.SDK];
The `userInfo` of the `NSNotification` object that is passed to the selector handling the notification is a dictionary containing both the old and new users (set to `NSNull.null` if logged out). This will only be triggered when the `uuid` of the attached user changes, not if a property of the user changes.


### Geolocation
Everything in the eTilbudsavis world is geolocation based, so it is **very** important that you set the geolocation on the ETA object, and keep it up to date. Even if you don't think it is relevant, please still send it, as the analytics are vital. The location info that you set will be sent with every subsequent API call. 

To update all the geolocation properties at once, use the following methods:

    [ETA.SDK setLatitude:55.631219
               longitude:12.577426 
                  radius:5000 
            isFromSensor:NO];      
If you wish to change each part separately, use these properties:

    ETA.SDK.geolocation = [[CLLocation alloc] initWithLatitude:55.631219 
                                                     longitude:12.577426];                                                  
    ETA.SDK.radius = @(5000);                      
    ETA.SDK.isLocationFromSensor = NO;


&nbsp;
## Shopping List Manager
> \#import "ETA_ShoppingListManager.h"

The world of Shopping Lists is a lot more complex than any of the other parts of the new API, so we provide the `ETA_ShoppingListManager` through which all ShoppingList related communication should happen.

You create an instance of the manager with `+managerWithETA:`, passing in the `ETA` SDK object. You will only really need to create one, and although multiple instances _should_ work, it is untested (they would be using the same local database).

### Polling & Syncing

The main job of the manager is keeping a local store of `ETA_ShoppingList` and `ETA_ShoppingListItem` objects in sync with the the server. It does this by polling the server at a regular interval for changes to the lists and items.

When something changes a notification will be triggered (see **[Notifications](#notifications)** section below).

You can change the rate of this polling using the `pollRate` property (for example, perhaps you want to slow down or stop the polling when not looking at the shopping lists).

##### Attached User
One major thing to note is that the behaviour of the `ETA_ShoppingListManager` is closely tied to the `ETA` object's `attachedUser` property (so if you pass nil when creating the manager you will only work locally). 

If there is no attached user, the manager will not be able to sync changes to the server, and so will not poll, and all changes you make will be saved to a 'userless' local store. As soon as a user is attached (by logging in) the changes that are now made will be saved to a 'user' local store, and also sent to the server. 

It is your responsibility to merge any changes from the 'userless' local store to server (perhaps asking the user which of their online lists they want to move the userless items to). To help with this migration there is a flag on the manager called `ignoreAttachedUser`. When set to YES the `ETA`'s user will not be taken into account, polling will be ignored, and any queries or actions will be applied to the 'userless' local store, and not passed to the server.

##### Failure handling
The server is always considered the truth when it comes to syncing. However, if there are changes on the client side we will not poll and ask the server for it's state until all those changes are successfully sent. 

Great effort has been made to make sure that if something goes wrong while sending a change request to the server it will not be lost. It will retry a number of times, and if that fails it will enter a slow retry cycle (this would happen if the app has gone offline). If the app shuts down before the changes are sent, when the manager starts again and logs in with the same user we will retry sending the changes before we start polling again. 

This may cause a problem if the user logs in with a different userID before the local changes for the previous user are sent. This is because there is only one local store for all users, and this is cleared and replaced with the server state when a different user logs in. Logging off and on with the same user will not be a problem.


### Methods

There are multiple `ETA_ShoppingList` and `ETA_ShoppingListItem` variants for each of the following methods:

##### `-get…`
All of the getters will give you the results from the local store, as up to date with the server as the last poll.

The objects that are returned by the getters are copies - changing properties will have no effect on the local store or server unless you pass the object back to one of the setter methods.

##### `-create…`
Initializes an object with a new `uuid`, calls the related `-add…` method, and returns the newly created object. Returns `nil` if it couldn't create the object.

##### `-add…`
This will actually just call `-update:`, but is useful for being explicit about your intentions.

##### `-update…`
If the passed in object doesn't exist in the local store (based on `uuid`) this will add it, and if a user is logged in it will try to send the request to server.

If the object already exists in the local store then the local store will be updated to use the values in the passed in object, and if a user is logged in it will send a request to update the object's properties on the server.

Before adding or updating, the object's `modified` date will be updated to the current date and time.

A notification will be triggered containing the object (see **[Notifications](#notifications)** section below). 

You would use this method whenever you change a property on an object (for example when ticking a shopping list item).

##### `-remove…` 
Removing an object will mark it as needing to be deleted from the local store, and send a delete request to the server. Only when the object is successfully deleted from the server is the object removed from the local store. Obviously, if there is no user logged in it is instantly removed from the local store.

A notification will be triggered containing the deleted object (see **[Notifications](#notifications)** section below). 

When removing a shopping list, all the items in that list will also be removed from the local store (the server will automatically take care of removing these orphaned items from the server). It will, however, only send a notification about the removal of the list, not the items.


### Notifications

Everytime something is changed, either by the server or locally, a notification is sent to `NSNotificationCenter`.

There are two notifications you can listen for:

- `ETA_ShoppingListManager_ListsChangedNotification` when lists changed
- `ETA_ShoppingListManager_ItemsChangedNotification` when items changed

The userInfo dictionary supplied with both notification types is of the same form - three lists of objects under the keys `added`, `removed` and `modified`. 

For example, if you got a `ETA_ShoppingListManager_ListsChangedNotification` notification, and want to get the objects that have just been added, `notification.userInfo[@"added"]` will give you an `NSArray` of `ETA_ShoppingList` objects (or `nil` if no lists were added).

The `modified` notification will be called for shopping lists whenever anything changes with any of the items contained within that list.


&nbsp;
## Catalog View
> \#import "ETA_CatalogView.h"

`ETA_CatalogView` is a UIView that contains all the functionality you need to show an interactive catalog.

First, simply add an instance of the `ETA_CatalogView` to a view. This will by default use the `ETA.SDK` singleton, but there are other `-init…` methods that allow you to use a different ETA instance, and also a different `baseURL` (to which "proxy/{UUID}/" is appended when loading the catalog).

Now, to show an interactive catalog, call `-loadCatalog:`, with the catalog's UUID. You can optionally pass in a starting page number or a dictionary of parameters.

You can change the catalog that is shown by simply calling `-loadCatalog:` again, though this will have no effect if the catalog is in the process of being loaded.

To close the catalog call `-closeCatalog`, or pass *nil* to `-loadCatalog:` - this will remove the catalog from the CatalogView, and also inform the server that the catalog was closed.

There are several properties to keep track of what page you are looking at. `currentPage` is the page number of the first visible page (starting at 1). `pageCount` is the total number of pages in the catalog. `pageProgress` is a float representing how far through the catalog you are from 0 to 1. When multiple pages are visible, the progress is taken from the last visible page. All these properties are 0 if no catalog is loaded.

Finally, the `-toggleCatalogThumbnails` will show an overlay of all the pages to allow the user to quickly pick the page they wish to go to.

### CatalogView events
If you want to know what the user is doing within the CatalogView, set your ViewController as the CatalogView's `delegate`, and implement as many of the (optional) `ETACatalogViewDelegate` methods as you need. 

A special delegate method is `-etaCatalogView:triggeredEventWithClass:type:dataDictionary:`. This will be triggered for **all** catalog events _unless_ you implement the corresponding delegate method. For example, if you implement the `-etaCatalogView:catalogViewSingleTapEvent:` delegate method you will not receive the `…triggeredEventWithClass:…` delegate call for that event.




&nbsp;
&nbsp;

---
*2013-07-26*