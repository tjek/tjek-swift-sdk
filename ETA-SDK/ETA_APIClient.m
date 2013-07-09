//
//  ETA_APIClient.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_APIClient.h"

#import "ETA.h"
#import "ETA_Session.h"

#import "AFJSONRequestOperation.h"

#import "NSString+SHA256Digest.h"

static NSString* const kETA_SessionUserDefaultsKey = @"ETA_Session";

static NSString* const kETA_APIPath_Sessions = @"/v2/sessions";

@interface ETA_APIClient ()

@property (nonatomic, readwrite, strong) NSString *apiKey;
@property (nonatomic, readwrite, strong) NSString *apiSecret;

@end


@implementation ETA_APIClient

+ (instancetype)clientWithApiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret
{
    return [self clientWithBaseURL:[NSURL URLWithString:kETA_APIBaseURLString]
                            apiKey:apiKey
                         apiSecret:apiSecret];
}

+ (instancetype)clientWithBaseURL:(NSURL *)url apiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret
{
    ETA_APIClient* client = [[ETA_APIClient alloc] initWithBaseURL:url];
    client.apiKey = apiKey;
    client.apiSecret = apiSecret;
    return client;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if ((self = [super initWithBaseURL:url]))
    {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        
        [self setDefaultHeader:@"Accept" value:@"application/json"];
        
        self.storageEnabled = YES;
    }
    return self;
}

// the parameters that are derived from the client, that may be overridded by the request
- (NSDictionary*) baseRequestParameters
{
    return @{};
}

// send a request, and on sucessful response update the session token, if newer
- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(NSDictionary* JSONResponse, NSError* error))completionHandler
{
    //TODO: REAL ERROR!
    if (!self.session)
        completionHandler(nil, [NSError errorWithDomain:@"" code:0 userInfo:nil]);
    
    // get the base parameters, and override them with those passed in
    NSMutableDictionary* mergedParameters = [[self baseRequestParameters] mutableCopy];
    [mergedParameters setValuesForKeysWithDictionary:parameters];
    
    
    void (^successBlock)(AFHTTPRequestOperation*, id) = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        [self updateSessionTokenFromHeaders:operation.response.allHeaderFields];
        
        completionHandler(responseObject, nil);
    };
    void (^failureBlock)(AFHTTPRequestOperation*, id) = ^(AFHTTPRequestOperation *operation, NSError *error)
    {
        completionHandler(nil, error);
    };
    
    switch (type)
    {
        case ETARequestTypeGET:
            [self getPath:requestPath parameters:mergedParameters success:successBlock failure:failureBlock];
            break;
        case ETARequestTypePOST:
            [self postPath:requestPath parameters:mergedParameters success:successBlock failure:failureBlock];
            break;
        case ETARequestTypePUT:
            [self putPath:requestPath parameters:mergedParameters success:successBlock failure:failureBlock];
            break;
        case ETARequestTypeDELETE:
            [self deletePath:requestPath parameters:mergedParameters success:successBlock failure:failureBlock];
            break;
        default:
            break;
    }
}


#pragma mark -
// When the secret changes, the headers must update
- (void) setApiSecret:(NSString *)apiSecret
{
    _apiSecret = apiSecret;
    
    [self updateHeaders];
}

// Update the client's headers to use the session's token
- (void) updateHeaders
{
    NSString* hash = nil;
    if (self.session.token && self.apiSecret)
    {
        hash = [[NSString stringWithFormat:@"%@%@", self.apiSecret, self.session.token] SHA256HexDigest];
    }
    
    [self setDefaultHeader:@"X-Token"       value:self.session.token];
    [self setDefaultHeader:@"X-Signature"   value:hash];
}


#pragma mark - Session Setters
- (void) setIfSameOrNewerSession:(ETA_Session *)session
{    
    if (session && [session isExpirySameOrNewerThanSession:self.session])
    {
        self.session = session;
    }
}

// Setting the session causes the change to be persisted to User Defaults
- (void) setSession:(ETA_Session *)session
{
    _session = session;
    
    [self updateHeaders];
    [self saveSessionToStorage];
}

// This will only update the session token/expiry if the expiry is newer
- (void) updateSessionTokenFromHeaders:(NSDictionary*)headers
{
    [self.session setToken:headers[@"X-Token"]
           ifExpiresBefore:headers[@"X-Token-Expires"]];
}

#pragma mark - Session Loading / Updating / Saving

// get the session, either from local storage or creating a new one, and make sure it's up to date
- (void) startSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    // fill self.session with the session from user defaults, or nil if not set
    [self loadSessionFromStorage];
    
    // if there is no session, or either renew or update fail, call this block, which tries to create a new session
    void (^createSessionBlock)() = ^{
        self.session = nil;
        [self createSessionWithCompletion:^(NSError *error) {
            if (error)
            {
                DLog(@"Unable to create session. Now what?");
            }
            completionHandler(error);
        }];
    };
    
    // no session stored, create one from scratch
    if (self.session)
    {   
        // if the session is out of date, renew it
        if ([self.session willExpireSoon])
        {
            [self renewSessionWithCompletion:^(NSError *error) {
                if (error)
                {
                    DLog(@"Unable to renew session - trying to create a new one instead: %@", error);
                    createSessionBlock();
                }
                else
                    completionHandler(error);
            }];
        }
        // otherwise, update it
        else
        {
            [self updateSessionWithCompletion:^(NSError *error) {
                if (error)
                {
                    DLog(@"Unable to update session - trying to create a new one instead: %@", error);
                    createSessionBlock();
                }
                else
                    completionHandler(error);
            }];
        }
    }
    // no previous session exists - create a new one
    else
    {
        createSessionBlock(nil);
    }
}

// get the session from UserDefaults
- (void) loadSessionFromStorage
{
    if (!self.storageEnabled)
        return;
    
    NSString* sessionJSON = [[NSUserDefaults standardUserDefaults] valueForKey:kETA_SessionUserDefaultsKey];
    NSDictionary* sessionDict = (sessionJSON) ? [NSJSONSerialization JSONObjectWithData:[sessionJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    ETA_Session* session = nil;
    if (sessionDict)
    {
        NSError* err = nil;
        session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:sessionDict error:&err];
        if (!err)
        {
            self.session = session;
            return;
        }
    }
    self.session = nil;
}

// save the session to local storage
- (void) saveSessionToStorage
{
    if (!self.storageEnabled)
        return;
    
    NSString* sessionJSON = nil;
    if (self.session)
    {
        NSDictionary* sessionDict = [MTLJSONAdapter JSONDictionaryFromModel:self.session];
        sessionJSON = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:sessionDict options:0 error:nil]
                                            encoding: NSUTF8StringEncoding];
    }
    [[NSUserDefaults standardUserDefaults] setObject: sessionJSON
                                              forKey:kETA_SessionUserDefaultsKey];
}
    
// create a new session, and assign
- (void) createSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self makeRequest:kETA_APIPath_Sessions
                 type:ETARequestTypePOST
           parameters:@{ @"api_key": (self.apiKey) ?: [NSNull null] }
           completion:^(NSDictionary *JSONResponse, NSError *error) {
               if (!error)
               {
                   ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:JSONResponse error:&error];
                   // save the session that was created, only if we have created it after any previous requests
                   if (!error)
                       [self setIfSameOrNewerSession:session];
               }
               completionHandler(error);
           }];
}

// get the latest state of the session
- (void) updateSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self makeRequest:kETA_APIPath_Sessions
                 type:ETARequestTypeGET
           parameters:nil
           completion:^(NSDictionary *JSONResponse, NSError *error) {
               if (!error)
               {
                   ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:JSONResponse error:&error];
                   // merge the updated session properties
                   if (!error)
                       [self setIfSameOrNewerSession:session];
               }
               completionHandler(error);
           }];
}

// Ask for a new expiration date / token
- (void) renewSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self makeRequest:kETA_APIPath_Sessions
                 type:ETARequestTypePUT
           parameters:nil
           completion:^(NSDictionary *JSONResponse, NSError *error) {
               if (!error)
               {
                   ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:JSONResponse error:&error];
                   if (!error)
                       [self setIfSameOrNewerSession:session];
               }
               completionHandler(error);
           }];
}

#pragma mark - Session User Management

- (void) attachUser:(NSDictionary*)userCredentials withCompletion:(void (^)(NSError* error))completionHandler
{
    if (!userCredentials)
        return;
    
    [self makeRequest:kETA_APIPath_Sessions
                 type:ETARequestTypePUT
           parameters:userCredentials
           completion:^(NSDictionary *JSONResponse, NSError *error) {
               if (!error)
               {
                   ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:JSONResponse error:&error];
                   if (!error)
                       [self setIfSameOrNewerSession:session];
               }
               completionHandler(error);
           }];
}


- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self makeRequest:kETA_APIPath_Sessions
                 type:ETARequestTypePUT
           parameters:@{ @"email":@"" }
           completion:^(NSDictionary *JSONResponse, NSError *error) {
               if (!error)
               {
                   ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:JSONResponse error:&error];
                   if (!error)
                       [self setIfSameOrNewerSession:session];
               }
               completionHandler(error);
           }];
}


@end
