# API Requests

> **Note:** You must first [initialise the SDK](GettingStarted.md#configure-the-sdk) before making API requests.


Documentation of the possible API calls can be found at [http://engineering.etilbudsavis.dk/eta-api/](http://engineering.etilbudsavis.dk/eta-api/).


## Making Requests

In order to make API requests you use the following method on an `ETA` instance:

```obj-c
- (void) api:(NSString*)requestPath 
        type:(ETARequestType)type 
  parameters:(NSDictionary*)parameters 
    useCache:(BOOL)useCache 
  completion:(void (^)(id response, NSError* error, BOOL fromCache))completionHandler;
```

- `requestPath` is a string containing the API request (optionally including "?key1=val1,key2=val2" style parameters)
- `type` describes how you want to send the request to the server: `GET`, `POST`, `PUT`, or `DELETE`
- `parameters` is an optional dictionary to be sent with the request. It will be merged with and override any "?key1=val1,key2=val2" parameters included in the `requestPath`. When using `GET` these will usually be filter or sort queries, while with `PUSH` it can be a JSON dictionary of a model object.
- `useCache` lets you choose whether to quickly try to first get results from the SDK's cache. See the **[Caching](#caching)** section below for more details.
- `completionHandler` is a callback that is called when the API request finishes (and possibly also when a result is found in the cache). It is called on the main queue. It provides the following values:
	- `response` is the JSON response from the server. It has been pre-parsed, and so can be in the form of an `NSArray`, `NSDictionary`, `NSNumber` or `NSString`. If something went wrong it will be `nil`.
	- `error` contains a description of the problem, if something went wrong. Otherwise it is `nil`.
	- `fromCache` shows whether or not the response came from the cache (as described in the **[Caching](#caching)** section below).


For example, to get an array of catalogs for some specific dealers, sorted by distance and then name, use the following call:

```obj-c
[ETA.SDK api: @"/v2/catalogs"
        type: ETARequestTypeGET
  parameters: @{ @"dealer_ids": @[@"d432U", @"1f30I"],
                 @"order_by":@[@"distance", @"name"] }
  completion:^(id response, NSError *error, BOOL fromCache) {
     NSLog(@"JSON Response: %@", response);
}];
```
*Note that this is using a variant of the `-api:…` method where `usesCache` is YES by default.*

See the [ETA-SDK Example project](ETA-SDK Example) for examples.

##### Caching
Every time an API call returns a valid object (when `useCache` is true), the JSON dictionary is saved to the cache, keyed on the object's `ern`. The next time an API call is made that is asking for a specific object or list of objects, the SDK looks in the cache for previous results matching the requested object. 

It will always still send the request to the server, but if it does find matching objects in the cache the `completionHandler` will be called twice, the `fromCache` property specifying whether the response came from the cache or not (the response will be a copy of the cache data). If you are asking for a list of objects, and not all of the objects are in the cache, it will be as if none of the objects are in the cache. 

Objects have a limited cache lifespan, and will not be returned if out of date (lifespan depends on the object type, but defaults to around 15mins). The cache will be cleaned of out-of-date objects at a regular interval, and whenever you request an object that is out-of-date. 

You can manually clear all objects from the cache by calling `-clearCache`, or just out of date objects with `-clearOutOfDateCache`. Note that clearing out of date objects iterates the entire cache, so should not be done regularly - you probably only want to do this if you get a low memory warning, in which case you should just clear the entire cache.


##### Endpoints
An Endpoint represents a component of an API request that results in a response. There is a utility class called `ETA_API` that provides a lot of useful information and shortcuts for the possible endpoints.

Mostly you will be using it to generate API request paths. For example, a more future proof method of generating the @"/v2/catalogs" request path string we used above would be as follows:

```obj-c
// @"/v2/catalogs"
NSString* requestPath = [ETA_API path: ETA_API.catalogs];
```

You can also chain endpoints as follows:

```obj-c
// @"/v2/offers/123abc/stores"
NSString* requestPath = [ETA_API pathWithComponents:@[ ETA_API.offers, @"123abc", ETA_API.stores ]];

```    



## Connecting
Before any API requests can be sent, the SDK must create a session. This is all done automatically the first time you send an API request, and all API requests you send will wait until the session is created. It will, however, mean that your first API call may slower than normal.

If you want to manually connect before you make any API calls, you can use the following method:

```obj-c
- (void) connect:(void (^)(NSError* error))completionHandler;
```

The `completionHandler` will be called (on the main queue) when the session is connected, and if it failed to connect `error` will be non-nil. Any future calls to `-connect:` will call the completionHandler instantly. If you make any API calls before the completionHandler is triggered they will just wait to be sent until the connect finishes.



## User login

Certain funtionality, such as shopping lists, behave differently when a user is logged in. You log a user in by attaching their userID to the current active session. All future API calls will then be in relation to that user.

Attach a user with the following method:

```obj-c
- (void) attachUserEmail:(NSString*)email 
                password:(NSString*)password 
              completion:(void (^)(NSError* error))completionHandler;
```

Where `email` is the email the user created their account with, and `password` is their password in plain text. When login finishes (successfully or not), the `completionHandler` is called on the main queue. If there was anything wrong with the login the `error` will provide information.

Once logged in you can access the user's information with the `attachedUser` property of the `ETA` instance. Note that this user is simply a copy of the current state, and changing it's properties will have no bearing on the attached user. You must always make API calls to affect state chages.

To logout, simply call `-detachUserWithCompletion:`.

##### User Change Notification
You can also listen for changes to the attached user in the `NSNotificationCenter`, by listening for the name `ETA_AttachedUserChangedNotification`. For example:

```obj-c
[NSNotificationCenter.defaultCenter addObserver:self
                                       selector:@selector(userChanged:)
                                           name:ETA_AttachedUserChangedNotification
                                         object:ETA.SDK];
```
                                         
The `userInfo` of the `NSNotification` object that is passed to the selector handling the notification is a dictionary containing both the old and new users (set to `NSNull.null` if logged out). This will only be triggered when the `uuid` of the attached user changes, not if a property of the user changes.


## Geolocation
Everything in the eTilbudsavis world is geolocation based, so it is **very** important that you set the geolocation on the ETA object, and keep it up to date. Even if you don't think it is relevant, please still send it, as the analytics are vital. The location info that you set will be sent with every subsequent API call. 

To update all the geolocation properties at once, use the following methods:

```obj-c
[ETA.SDK setLatitude:55.631219
           longitude:12.577426 
              radius:5000 
        isFromSensor:NO];      
```

If you wish to change each part separately, use these properties:

```obj-c
ETA.SDK.geolocation = [[CLLocation alloc] initWithLatitude:55.631219 
                                                 longitude:12.577426];                                                  
ETA.SDK.radius = @(5000);                      
ETA.SDK.isLocationFromSensor = NO;
```

