//
//  ETA.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "ETA_API.h"
@class ETA_User;



typedef enum {
    ETARequestTypeGET,
    ETARequestTypePOST,
    ETARequestTypePUT,
    ETARequestTypeDELETE
} ETARequestType;

static NSString * const kETA_APIBaseURLString = @"https://api.etilbudsavis.dk/";
extern NSString* const ETA_AttachedUserChangedNotification;



@interface ETA : NSObject

// Returns the ETA SDK singleton
+ (ETA*)SDK;

// You must call one of theses with an API key & secret BEFORE you ask for the ETA.SDK singleton, otherwise you will just get nil.
// After the first call this be a no-op.
+ (void) initializeSDKWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret;
+ (void) initializeSDKWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret baseURL:(NSURL*)baseURL;


#pragma mark - Sending API Requests

// Send a request to the server.
// Creates a session if one doesnt exist already, pausing all future api requests until created.
// If looking for items it will first check the cache for them.
// If found it will first send the item from the cache, and ALSO send the request to the server (expect 1 or 2 completionHandler events)
- (void) api: (NSString*)requestPath
        type: (ETARequestType)type
  parameters: (NSDictionary*)parameters
    useCache: (BOOL)useCache
  completion: (void (^)(id response, NSError* error, BOOL fromCache))completionHandler;

// Send an API request with caching enabled
- (void) api:(NSString*)requestPath
        type:(ETARequestType)type
  parameters:(NSDictionary*)parameters
  completion:(void (^)(id response, NSError* error, BOOL fromCache))completionHandler;



#pragma mark - Connecting

// start a session. This is not required, as any API/user requests that you make will create the session automatically.
// you would use this method to avoid a slow first API request
- (void) connect:(void (^)(NSError* error))completionHandler;


#pragma mark - User Management

// Try to set the current user of the session to be that with the specified email/pass
// Creates a session if one doesnt exist already.
- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler;
// remove the user from the current session
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler;

// the ID of the user that is attached
- (NSString*) attachedUserID;
// a copy of the user object that has been attached (changes to this user have no effect)
- (ETA_User*) attachedUser;

// does the currently attached user allow the specified action. NO if no user attached.
- (BOOL) allowsPermission:(NSString*)actionPermission;



#pragma - Geolocation

// Changes to any of the location properties will be applied to all future requests.
// There will be no location info sent by default.
@property (nonatomic, readwrite, strong) CLLocation* geolocation;

// Radius will only be sent if there is also a location to send.
@property (nonatomic, readwrite, strong) NSNumber* radius; // meters

// 'isLocationFromSensor' is currently just metadata for the server.
// Set to YES if the location property comes from the device's sensor.
@property (nonatomic, readwrite, assign) BOOL isLocationFromSensor;

// A utility geolocation setter method
- (void) setLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude radius:(CLLocationDistance)radius isFromSensor:(BOOL)isFromSensor;

// A list of the radiuses that we prefer to use.
// The 'radius' property will be clamped to within these numbers before being sent
+ (NSArray*) preferredRadiuses;



#pragma mark - Non-Singleton constructors
// Construct an ETA object - use these if you want multiple ETA objects, for some reason
+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret;
+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret baseURL:(NSURL*)baseURL;




#pragma mark - Caching
// remove all the objects from the cache
- (void) clearCache;

// remove all the old objects from the cache - automatically triggered, and slow, so use sparingly
- (void) clearOutOfDateCache;



#pragma mark - Errors
// a dictionary of all the ETA error names, keyed by their codes
+ (NSDictionary*) errors;

// quick access to the name of an error, based on it's code.
+ (NSString*) errorForCode:(NSUInteger)errorCode;



#pragma mark - Instance properties
@property (nonatomic, readonly, strong) NSURL* baseURL;
@property (nonatomic, readonly, strong) NSString* apiKey;
@property (nonatomic, readonly, strong) NSString* apiSecret;

// whether the SDK logs errors and events. Defaults to NO.
@property (nonatomic, readwrite, assign) BOOL verbose;
@end

