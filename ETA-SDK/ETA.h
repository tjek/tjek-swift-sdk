//
//  ETA.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "SGN_APIErrors.h"
#import "ETA_Log.h"
#import "ETA_API.h"

@class ETA_User;


/**
 *	The possible API request types you can make with -api:type:parameters:useCache:completion:
 */
typedef enum {
    ETARequestTypeGET,
    ETARequestTypePOST,
    ETARequestTypePUT,
    ETARequestTypeDELETE
} ETARequestType;


typedef void (^ETA_RequestCompletionBlock)(id, NSError *, BOOL);

/**
 *	Whenever the attached user ID changes (because a user has logged in or out), an NSNotification with this name is sent to the NSNotificationCenter (the object of the notification is the ETA object to which the user is attached).
 */
extern NSString* const ETA_AttachedUserChangedNotification;

/**
 *	This is the default `baseURL` that is used by the SDK. All API requests are appended to this URL.
 */
static NSString * const kETA_APIBaseURLString = @"https://api.etilbudsavis.dk/";




/**
 `ETA` is the main interface into the eTilbudsavis API. It handles all the boring session management stuff, freeing you to make API requests, and handle the data when it is returned.
 
 The best way to get an instance of the ETA class is through the shared singleton. After initializing it, simply call *ETA.SDK*.
 
 It is *HIGHLY* recommended that you always keep the geolocation properties up to date.
 */
@interface ETA : NSObject


#pragma mark - Getting and Initializing the shared ETA SDK
///---------------------------------------------
/// @name Getting and Initializing the shared ETA SDK
///---------------------------------------------


/**
 *	Returns the shared ETA singleton object
 *
 *  This will return `nil` until `+initializeSDKWith...` is called.
 *
 *	@return	The shared ETA singleton object
 *
 *  @see +initializeSDKWithAPIKey:apiSecret:
 *  @see +initializeSDKWithAPIKey:apiSecret:baseURL:
 */
+ (ETA*)SDK;


/**
 *	Initialize the shared ETA singleton object
 *
 *  This will call `+initializeSDKWithAPIKey:apiSecret:baseURL:` with the default API baseURL: `kETA_APIBaseURLString`
 *
 *  You must call one of the `+initializeSDKWith...` methods before calling `ETA.SDK`.
 *  After the first call this will be a no-op.
 *
 *	@param	apiKey	The API Key you received when registering your app at http://etilbudsavis.dk/developers/
 *	@param	apiSecret	The API Secret you received when registering your app at http://etilbudsavis.dk/developers/
 *
 *  @see +SDK
 *  @see +initializeSDKWithAPIKey:apiSecret:baseURL:
 */
+ (void) initializeSDKWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion;


/**
 *	Initialize the shared ETA singleton object
 *
 *  You must call one of the `+initializeSDKWith...` methods before calling `ETA.SDK`.
 *  After the first call this will be a no-op.
 *
 *	@param	apiKey	The API Key you received when registering your app at `http://etilbudsavis.dk/developers/`
 *	@param	apiSecret	The API Secret you received when registering your app at `http://etilbudsavis.dk/developers/`
 *  @param  baseURL The url on which all API requests are made.
 *
 *  @see +SDK
 *  @see +initializeSDKWithAPIKey:apiSecret:
 */
+ (void) initializeSDKWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion baseURL:(NSURL*)baseURL;



+ (ETASDK_LogLevel) logLevel;
+ (void) setLogLevel:(ETASDK_LogLevel)logLevel;




#pragma mark - Sending API Requests
///---------------------------------------------
/// @name Sending API Requests
///---------------------------------------------


/**
 *	Send an API request to the server
 *
 * This creates a session if one doesnt exist already, pausing all future api requests until created.
 *
 * If the request is a query that will result in one or more `ETA_ModelObject` items, it will first check the cache for them. If found it will first send the item from the cache, and ALSO send the request to the server (expect 1 or 2 completionHandler events, the `fromCache` flag in the completionHandler defining where the results came from).
 *
 *
 *	@param	requestPath	A string defining the API endpoint path (that will be appended to the `baseURL` defined in the initialization). *Required*
 *	@param	type	What sort of network request are you making? Choose from: ETARequestTypeGET / POST / PUT / DELETE
 *	@param	parameters	An *optional* dictionary of parameters that are sent with the request. Keys must be NSStrings, and values can be of type NSString, NSNumber, or NSArray (in which case they are parsed into a comma-separated string).
 *	@param	useCache	A BOOL that specifies whether to first try to quickly get the results from, and save server responses to, the cache.
 *	@param	completionHandler	Called on the main queue both when the server responds, and *possibly* if result items are found from the cache. The `response` parameter will contain the JSON response from the server (an NSString, NSArray, NSNumber, NSDictionary, or NSNull, depending on the request), or `nil` if something went wrong. `error` will only be non-nil if something went wrong. `fromCache` tells you if the `response` parameter is coming from the cache rather than the server.
 *
 *  @see -api:type:parameters:completion:
 */
- (void) api: (NSString*)requestPath
        type: (ETARequestType)type
  parameters: (NSDictionary*)parameters
    useCache: (BOOL)useCache
  completion: (ETA_RequestCompletionBlock)completionHandler;

/**
 *	Send an API request to the server, with caching turned on.
 *
 *  This calls -api:type:parameters:useCache:completion: with `useCache` set to YES
 *
 *	@param	requestPath	A string defining the API endpoint path (that will be appended to the `baseURL` defined in the initialization). *Required*
 *	@param	type	What sort of network request are you making? Choose from: ETARequestTypeGET / POST / PUT / DELETE
 *	@param	parameters	An *optional* dictionary of parameters that are sent with the request. Keys must be NSStrings, and values can be of type NSString, NSNumber, or NSArray (in which case they are parsed into a comma-separated string).
 *	@param	completionHandler	Called on the main queue both when the server responds, and *possibly* if result items are found from the cache. The `response` parameter will contain the JSON response from the server (an NSString, NSArray, NSNumber, NSDictionary, or NSNull, depending on the request), or `nil` if something went wrong. `error` will only be non-nil if something went wrong. `fromCache` tells you if the `response` parameter is coming from the cache rather than the server.
 *
 *  @see -api:type:parameters:useCache:completion:
 */
- (void) api:(NSString*)requestPath
        type:(ETARequestType)type
  parameters:(NSDictionary*)parameters
  completion:(ETA_RequestCompletionBlock)completionHandler;



#pragma mark - Connecting
///---------------------------------------------
/// @name Connecting
///---------------------------------------------


/**
 *	Start a session, if one isnt already started.
 *
 *  This is not required, as any API/user requests that you make will create the session automatically. You would use this method to avoid a slow first API request.
 *
 *	@param	completionHandler	Called on the main queue when the session is started. If a session is already started this will be triggered instantly
 */
- (void) connect:(void (^)(NSError* error))completionHandler;



/**
 *	Whether the SDK is connected and a session has been created. Observable.
 */
@property (nonatomic, readonly, assign) BOOL connected;



#pragma mark - User Management
///---------------------------------------------
/// @name User Management
///---------------------------------------------

/**
 *	Try to set the current user of the session to be that with the specified email/pass (eg. log in)
 *
 *  Creates a session if one doesnt exist already.
 *
 *	@param	email	The user's email address
 *	@param	password	The user's password (in plain text)
 *	@param	completionHandler	Called on the main queue when the server responds. If failed to log in `error` will be non-nil.
 */
- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler;

- (void) attachUserWithFacebookToken:(NSString*)facebookToken completion:(void (^)(NSError* error))completionHandler;


/**
 *	Remove the user from the current session (eg. log out)
 *
 *	@param	completionHandler	Called on the main queue when the server responds. If failed to log out `error` will be non-nil.
 */
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler;

/**
 *	The ID of the currently attached user. `nil` if no attached user. See `ETA_AttachedUserChangedNotification` to get NSNotifications when the userID changes.
 */
@property (nonatomic, readonly, copy) NSString* attachedUserID;

/**
 *	A copy of the user object that has been attached (changes to this user have no effect on the session's user)
 */
@property (nonatomic, readonly, copy) ETA_User* attachedUser;

/**
 * Is the user attached with a facebook token? (not observable)
 */
@property (nonatomic, readonly, assign) BOOL attachedUserIsFromFacebook;

/**
 *	Do the current session's permissions allow for the specified action?
 *
 *	@param	actionPermission	The action we want to check. eg. @"api.users.create"
 *
 *	@return	Whether the current session allows the specified permission. Returns NO if not connected.
 */
- (BOOL) allowsPermission:(NSString*)actionPermission;



#pragma - Geolocation
///---------------------------------------------
/// @name Geolocation
///---------------------------------------------


/**
 *	The geolocational context for all API results
 *
 *  The lat/long of this geolocation is sent with every API request, and helps to specify which results are return.
 *  Changes will be applied to future requests. 
 *  `nil` by default.
 */
@property (nonatomic, readwrite, strong) CLLocation* geolocation;


/**
 *	The range around `geolocation` (in meters) that the server should look for results
 *
 *  If `geolocation` is nil `radius` will not be sent.
 *  Radius is `nil` by default.
 */
@property (nonatomic, readwrite, strong) NSNumber* radius; // meters


/**
 *	Do the `geolocation` and `radius` properties come from a device's sensor?
 */
@property (nonatomic, readwrite, assign) BOOL isLocationFromSensor;


/**
 *	A utility geolocation setter method, for setting `geolocation`, `radius`, and `isLocationFromSensor` at the same time.
 *
 *	@param	latitude	The latitude of the geolocation
 *	@param	longitude	The longitude of the geolocation
 *	@param	radius	The radius of future search results
 *	@param	isFromSensor	Do these lat/long/radius properties come from a device's sensor?
 */
- (void) setLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude radius:(CLLocationDistance)radius isFromSensor:(BOOL)isFromSensor;


/**
 *	A list of the radiuses (in meters) that we prefer to use.
 *
 *  The `radius` property will be clamped to within these numbers before being sent to the server.
 *
 *	@return	An NSArray of NSNumbers - the radiuses (in meters) that we prefer to use
 */
+ (NSArray*) preferredRadiuses;



@property (nonatomic, readonly, strong) NSURL* unsubscribeURLForCurrentLocation;


#pragma mark - Non-Singleton constructors
///---------------------------------------------
/// @name Non-Singleton constructors
///---------------------------------------------


/**
 *	Construct a new ETA object
 *
 *  Use this if you want multiple ETA objects, for some reason.
 *
 *  It basically does the same as the `+initializeSDKWith...` methods, except with a new instance rather than the shared singleton.
 *
 *	@param	apiKey	The API Key you received when registering your app at `http://etilbudsavis.dk/developers/`
 *	@param	apiSecret	The API Secret you received when registering your app at `http://etilbudsavis.dk/developers/`
 *
 *	@return	A new instance of the ETA class.
 *
 *  @see +etaWithAPIKey:apiSecret:baseURL:
 *  @see +initializeSDKWithAPIKey:apiSecret:
 */
+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion;

/** *	Construct a new ETA object
 *
 *  Use this if you want multiple ETA objects, for some reason.
 *
 *  It basically does the same as the `+initializeSDKWith...` methods, except with a new instance rather than the shared singleton.
 *
 *	@param	apiKey	The API Key you received when registering your app at `http://etilbudsavis.dk/developers/`
 *	@param	apiSecret	The API Secret you received when registering your app at `http://etilbudsavis.dk/developers/`
 *  @param  baseURL The url on which all API requests are made.
 *
 *	@return	A new instance of the ETA class.
 *
 *  @see +etaWithAPIKey:apiSecret:
 *  @see +initializeSDKWithAPIKey:apiSecret:baseURL:
 */
+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion baseURL:(NSURL*)baseURL;




#pragma mark - Instance properties
///---------------------------------------------
/// @name Instance properties
///---------------------------------------------

/**
 *	The url on which all API requests are made. Set when initializing. Defaults to `kETA_APIBaseURLString`.
 */
@property (nonatomic, readonly, strong) NSURL* baseURL;

/**
 *	The API Key used to talk to the server. Set when initializing.
 */
@property (nonatomic, readonly, strong) NSString* apiKey;

/**
 *	The API Secret used to talk to the server. Set when initializing.
 */
@property (nonatomic, readonly, strong) NSString* apiSecret;

/**
 * The version of the app that is using the SDK. Set when initializing.
 */
@property (nonatomic, readonly, strong) NSString* appVersion;


@end


