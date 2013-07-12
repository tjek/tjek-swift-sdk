//
//  ETA_APIClient.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "AFHTTPClient.h"

typedef enum {
    ETARequestTypeGET,
    ETARequestTypePOST,
    ETARequestTypePUT,
    ETARequestTypeDELETE
} ETARequestType;

static NSString * const kETA_APIBaseURLString = @"https://api.etilbudsavis.dk/";

@class ETA_Session;
@interface ETA_APIClient : AFHTTPClient

// Create the ETA_APIClient with these methods. Do not use init as apiKey/Secret must be set before further session can be started.
+ (instancetype)clientWithApiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret; // using the production base URL
+ (instancetype)clientWithBaseURL:(NSURL *)url apiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret;


#pragma mark - API Requests

// send a request to the server. This will start a session if not already started
- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError* error))completionHandler;


#pragma mark - Session

// The current session. nil until connected. Do not modify directly.
@property (nonatomic, readonly, strong) ETA_Session* session;

// Whether we should read and save the session to UserDefaults. Defaults to YES.
@property (nonatomic, readwrite, assign) BOOL storageEnabled;

// try to start a session. This must be performed before any requests can be made.
- (void) startSessionWithCompletion:(void (^)(NSError* error))completionHandler;


#pragma mark - User Management
// try to add a user to the session.
- (void) attachUser:(NSDictionary*)userCredentials withCompletion:(void (^)(NSError* error))completionHandler;

// try to remove the user from the session
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler;

// does the current session allow the specified action
- (BOOL) allowsPermission:(NSString*)actionPermission;




@end
