//
//  ETA_APIClient.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_APIClient.h"

#import "ETA.h"

#import "ETA_Session.h"
#import "ETA_API.h"
#import "NSValueTransformer+ETAPredefinedValueTransformers.h"

#import "ETA_Log.h"

#import <CommonCrypto/CommonDigest.h>

static NSString* const kETA_AuthSessionUserDefaultsKey = @"ETA_Session";
static NSString* const kETA_ClientIDUserDefaultsKey = @"ETA_ClientID";


@interface ETA_APIClient ()

@property (nonatomic, readwrite, strong) NSString *apiKey;
@property (nonatomic, readwrite, strong) NSString *apiSecret;
@property (nonatomic, readwrite, strong) NSString *appVersion;

@end


@implementation ETA_APIClient
{
    dispatch_semaphore_t _startingSessionLock;
    dispatch_queue_t _syncQueue;
}


#pragma mark - Constructors

+ (instancetype)clientWithApiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret appVersion:(NSString*)appVersion
{
    return [self clientWithBaseURL:[NSURL URLWithString:kETA_APIBaseURLString]
                            apiKey:apiKey
                         apiSecret:apiSecret
                        appVersion:appVersion];
}

+ (instancetype)clientWithBaseURL:(NSURL *)url apiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret appVersion:(NSString*)appVersion
{
    ETA_APIClient* client = [[ETA_APIClient alloc] initWithBaseURL:url];
    client.apiKey = apiKey;
    client.apiSecret = apiSecret;
    client.appVersion = appVersion;
    return client;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if ((self = [super initWithBaseURL:url]))
    {
        _syncQueue = dispatch_queue_create("com.eTilbudsavis.ETA_APIClient.syncQ", 0);
        
        _startingSessionLock = dispatch_semaphore_create(1);
        
        self.responseSerializer = [AFJSONResponseSerializer serializer];
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        self.requestSerializer.timeoutInterval = 20;
        [self.requestSerializer setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
        
        self.storageEnabled = YES;
    }
    return self;
}


+ (NSString*) clientID
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kETA_ClientIDUserDefaultsKey];
}

+ (void) setClientID:(NSString*)clientID
{
    [[NSUserDefaults standardUserDefaults] setObject:clientID forKey:kETA_ClientIDUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - API Requests

// the parameters that are derived from the client, that may be overridded by the request
- (NSDictionary*) baseRequestParameters
{
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    if (self.appVersion)
        params[@"api_av"] = self.appVersion;
    
    NSString* locale = NSLocale.autoupdatingCurrentLocale.localeIdentifier;
    if (locale)
        params[@"r_locale"] = locale;
    
    return params;
}
// send a request, and on sucessful response update the session token, if newer
- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(id JSONResponse, NSError* error))completionHandler
{
    [self makeRequest:requestPath type:type parameters:parameters remainingRetries:1 completion:completionHandler];
}
// send a request, and on sucessful response update the session token, if newer
- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters remainingRetries:(NSUInteger)remainingRetries completion:(void (^)(id JSONResponse, NSError* error))completionHandler
{
    // push the makeRequest to the sync queue, which will be blocked while creating sessions
    // as it is quickly sent on to AFNetworking's operation queue, it wont block the sync queue for long
    dispatch_async(_syncQueue, ^{
        
        // the code that does the actual sending of the request
        void (^sendBlock)() = ^{
            // get the base parameters, and override them with those passed in
            NSMutableDictionary* mergedParameters = [[self baseRequestParameters] mutableCopy];
            [mergedParameters setValuesForKeysWithDictionary:parameters];
            
            // convert any arrays into a comma separated list
            NSMutableDictionary* cleanedParameters = [NSMutableDictionary dictionary];
            [mergedParameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isKindOfClass:[NSArray class]])
                {
                    obj = [obj componentsJoinedByString:@","];
                }
                [cleanedParameters setValue:obj forKey:key];
            }];
                        
            void (^successBlock)(NSURLSessionTask *, id) = ^(NSURLSessionTask *task, id responseObject)
            {
                // hopefully nil if not an error-object in the responseObj
                NSError* apiError = [NSError SGN_errorWithAPIJSONResponse:responseObject urlResponse:task.response];
                NSHTTPURLResponse* httpResponse = [task.response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse*)task.response : nil;
                
                [self updateAuthSessionTokenFromHeaders:httpResponse.allHeaderFields];
                if (completionHandler)
                    completionHandler(responseObject, apiError);
            };
            void (^failureBlock)(NSURLSessionTask *, id) = ^(NSURLSessionTask *task, NSError *networkError)
            {
                // may be nil if not an api error
                NSError* apiError = [NSError SGN_errorWithAPIJSONData:networkError.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] urlResponse:task.response];
                
                if (remainingRetries > 0)
                {
                    if ([apiError SGN_doesAPIResponseErrorRequireNewAuthSession])
                    {
                        ETASDKLogWarn(@"Error (%zd) while making request '%@' - Reset Session and retry '%@' - %@", apiError.code, requestPath, apiError.localizedDescription, apiError.localizedFailureReason);
                        // create a new session, and if it was successful, repeat the request we were making
                        [self startAuthSessionOnSyncQueue:YES forceReset:YES withCompletion:^(NSError *startSessionError) {
                            if (!startSessionError)
                            {
                                [self makeRequest:requestPath type:type parameters:parameters remainingRetries:remainingRetries-1 completion:^(id response, NSError *retryError) {
                                    if (retryError)
                                        ETASDKLogError(@"Error (%zd) Retrying Request: '%@'... %@ - %@", retryError.code, requestPath, retryError.localizedDescription, retryError.localizedFailureReason);
                                    completionHandler(response, retryError);
                                }];
                            }
                            else
                            {
                                completionHandler(nil, startSessionError);
                            }
                        }];
                        return;
                    }
                    // errors that require a retry
                    else if (apiError.code == SGN_APIError_InternalNonCriticalError)
                    {
                        // find how long until we retry - if not set then will retry instantly
                        NSInteger retryAfter = apiError.retryAfterSeconds;
                        
                        ETASDKLogWarn(@"Non-critical error(%zd) while making request (retrying after %tu secs): %@ - %@", apiError.code, retryAfter, apiError.localizedDescription, apiError.localizedFailureReason);
                        
                        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(retryAfter * NSEC_PER_SEC));
                        dispatch_after(popTime, _syncQueue, ^(void){
                            [self makeRequest:requestPath type:type parameters:parameters remainingRetries:remainingRetries-1 completion:completionHandler];
                        });
                        return;
                    }
                }
                
                // an unsolveable error, or ran our of retries - eject!
                if (completionHandler)
                {
                    completionHandler(nil, apiError ?: networkError);
                }
            };
            
            switch (type)
            {
                case ETARequestTypeGET:
                    [self GET:requestPath parameters:cleanedParameters progress:nil success:successBlock failure:failureBlock];
                    break;
                case ETARequestTypePOST:
                    [self POST:requestPath parameters:cleanedParameters progress:nil success:successBlock failure:failureBlock];
                    break;
                case ETARequestTypePUT:
                    [self PUT:requestPath parameters:cleanedParameters success:successBlock failure:failureBlock];
                    break;
                case ETARequestTypeDELETE:
                    [self DELETE:requestPath parameters:cleanedParameters success:successBlock failure:failureBlock];
                    break;
                default:
                    break;
            }
        };
        
        // the session hasnt been created, or it failed when previously created
        // try to create the session from scratch.
        // we are currently on the syncQ, so dont syncronously dispatch the start to the syncQ
        if (!self.authSession)
        {
            [self startAuthSessionOnSyncQueue:NO forceReset:NO withCompletion:^(NSError *error) {
                // if we were able to create the session, do the send request
                if (!error)
                    sendBlock();
                // if the creation failed, send the error up to the request
                else if (completionHandler)
                    completionHandler(nil, error);
            }];
            
            dispatch_semaphore_signal(_startingSessionLock);
        }
        // we have a session, so just run the sendBlock
        else
        {
            sendBlock();
        }
    });
}



#pragma mark - Headers

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
    if (self.authSession.token && self.apiSecret)
    {
        // try to make an SHA256 Hex string
        NSData* hashData = [[NSString stringWithFormat:@"%@%@", self.apiSecret, self.authSession.token] dataUsingEncoding:NSUTF8StringEncoding];
        
        unsigned char result[CC_SHA256_DIGEST_LENGTH];
        if (CC_SHA256(hashData.bytes, (CC_LONG)hashData.length, result)) {
            NSMutableString *res = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
            for (int i = 0; i<CC_SHA256_DIGEST_LENGTH; i++) {
                [res appendFormat:@"%02x",result[i]];
            }
            hash = [NSString stringWithString: res];
        }
    }
    
    
    NSDictionary* httpheaders = self.requestSerializer.HTTPRequestHeaders;
    
    ETASDKLogInfo(@"Updating Headers - Token:'%@'->'%@' Sig:'%@'->'%@'", httpheaders[@"X-Token"], self.authSession.token, httpheaders[@"X-Signature"], hash);
    
    [self.requestSerializer setValue:self.authSession.token forHTTPHeaderField:@"X-Token"];
    [self.requestSerializer setValue:hash                   forHTTPHeaderField:@"X-Signature"];
}




#pragma mark - Session Setters

- (void) setIfSameOrNewerAuthSession:(ETA_Session *)authSession
{
    if ([authSession isExpiryTheSameAsSession:self.authSession] ||
        [authSession isExpiryNewerThanSession:self.authSession])
    {
        self.authSession = authSession;
    }
}
- (void) setIfNewerAuthSession:(ETA_Session *)authSession
{
    if ([authSession isExpiryNewerThanSession:self.authSession])
    {
        self.authSession = authSession;
    }
}


// Setting the session causes the change to be persisted to User Defaults
- (void) setAuthSession:(ETA_Session *)authSession
{
    ETASDKLogInfo(@"Setting Session '%@' (%@) => '%@' (%@)", _authSession.token, _authSession.expires, authSession.token, authSession.expires);
    
    _authSession = authSession;
    [self updateHeaders];
    [self saveAuthSessionToStorage];
}

// This will only update the session token/expiry if the expiry is newer
- (void) updateAuthSessionTokenFromHeaders:(NSDictionary*)headers
{
    NSString* newToken = headers[@"X-Token"];
    
    NSDate* newExpiryDate = [ETA_API.dateFormatter dateFromString:headers[@"X-Token-Expires"]];
    
    if (!newExpiryDate || !newToken)
        return;
    
    // check if it would change anything about the session.
    // if the tokens are the same and the new date is not newer then it's a no-op
    if ([self.authSession.token isEqualToString:newToken])
        return;
    if (self.authSession.expires && [newExpiryDate compare: self.authSession.expires]!=NSOrderedDescending)
        return;
        
    // merge the expiry/token with the current session
    ETA_Session* newSession = [self.authSession copy];
    [newSession setValuesForKeysWithDictionary:@{@"token":newToken,
                                                 @"expires":newExpiryDate}];
    
    ETASDKLogInfo(@"Updating Session Tokens - '%@' (%@) => '%@' (%@)", self.authSession.token, self.authSession.expires, newSession.token, newSession.expires);
    self.authSession = newSession;
}

#pragma mark - Session Loading / Updating / Saving

// get the session, either from local storage or creating a new one, and make sure it's up to date
// it will perform it on the sync queue
- (void) startAuthSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self startAuthSessionOnSyncQueue:YES forceReset:NO withCompletion:completionHandler];
}

- (void) startAuthSessionOnSyncQueue:(BOOL)dispatchOnSyncQ forceReset:(BOOL)forceReset withCompletion:(void (^)(NSError* error))completionHandler
{
    // do it on the sync queue, and block until the completion occurs - that way any other requests will have to wait for the session to have started
    void (^block)() = ^{
        // we are asking to reset the session - just delete existing session
        if (forceReset)
        {
            self.authSession = nil;
        }
        // a previous connect was sucessful - dont bother connecting (and dont block syncQ with completion handler
        else if (self.authSession)
        {
            if (completionHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil);
                });
            }
            return;
        }
        
        // create a semaphore, so that the queue's block doesn't end until the completion handler is hit
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        
        // fill self.session with the session from user defaults, or nil if not set
        [self loadAuthSessionFromStorage];
        
        // if there is no session, or either renew or update fail, call this block, which tries to create a new session
        void (^createAuthSessionBlock)() = ^{
            ETASDKLogInfo(@"Resetting session before creating - '%@' => '%@'", self.authSession.token, nil);
            self.authSession = nil;
            [self createAuthSessionWithCompletion:^(NSError *error) {
//                if (error)
//                {
//                    ETASDKLogWarn(@"Unable to create session: (%d) %@ - %@", error.code, error.localizedDescription, error.localizedFailureReason);
//                }
                dispatch_semaphore_signal(sema); // tell the syncQueue block to finish
                if (completionHandler)
                    completionHandler(error);
            }];
        };
        
        // session loaded from local store - check its state
        if (self.authSession)
        {
//            // if the session is out of date, renew it
//            if ([self.session willExpireSoon])
//            {
                [self renewAuthSessionWithCompletion:^(NSError *error) {
                    if ([error SGN_doesAPIResponseErrorRequireNewAuthSession])
                    {
                        ETASDKLogWarn(@"Unable to renew session - trying to create a new one instead: (%zd) %@ - %@", error.code, error.localizedDescription, error.localizedFailureReason);
                        createAuthSessionBlock();
                    }
                    else
                    {
                        dispatch_semaphore_signal(sema); // tell the syncQueue block to finish
                        if (completionHandler)
                            completionHandler(error);
                    }
                }];
//            }
//            // if not out of date, update it
//            else
//            {
//                [self updateSessionWithCompletion:^(NSError *error) {
//                    if (error && error.code != NSURLErrorNotConnectedToInternet)
//                    {
//                        [self log: @"Unable to update session - trying to create a new one instead: %@", error.localizedDescription];
//                        createSessionBlock();
//                    }
//                    else
//                    {
//                        dispatch_semaphore_signal(sema); // tell the syncQueue block to finish
//                        if (completionHandler)
//                            completionHandler(error);
//                    }
//                }];
//            }
        }
        // no previous session exists - create a new one
        else
        {
            createAuthSessionBlock();
        }
        
        // wait for the semaphore that is going to be called when the getting of the session completes
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    };
    
    if (dispatchOnSyncQ)
        dispatch_async(_syncQueue, block);
    else
        block();
}

// get the session from UserDefaults
- (void) loadAuthSessionFromStorage
{
    if (!self.storageEnabled)
        return;
    
    NSString* sessionJSON = [[NSUserDefaults standardUserDefaults] valueForKey:kETA_AuthSessionUserDefaultsKey];
    NSDictionary* sessionDict = (sessionJSON) ? [NSJSONSerialization JSONObjectWithData:[sessionJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    ETA_Session* authSession = nil;
    if (sessionDict)
    {
        authSession = [ETA_Session objectFromJSONDictionary:sessionDict];
    }
    ETASDKLogInfo(@"Loading Session - '%@' => '%@'", self.authSession.token, authSession.token);
    self.authSession = authSession;
}

// save the session to local storage
- (void) saveAuthSessionToStorage
{
    if (!self.storageEnabled)
        return;
    
    NSString* sessionJSON = nil;
    if (self.authSession)
    {
        NSDictionary* sessionDict = [self.authSession JSONDictionary];
        
        sessionJSON = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:sessionDict options:0 error:nil]
                                            encoding: NSUTF8StringEncoding];
    }
    [[NSUserDefaults standardUserDefaults] setObject: sessionJSON
                                              forKey:kETA_AuthSessionUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
    
// create a new session, and assign
- (void) createAuthSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    NSInteger tokenLife = 90*24*60*60;
//    NSInteger tokenLife = 5;
    
    NSMutableDictionary* params = [[self baseRequestParameters] mutableCopy];
    
    [params setValuesForKeysWithDictionary:@{ @"api_key": (self.apiKey) ?: [NSNull null],
                                              @"token_ttl": @(tokenLife) }];
    
    // if we have a client ID send it as a parameter
    NSString* clientID = [self.class clientID];
    if (clientID)
        params[@"client_id"] = clientID;
    
    // legacy upgrade params
    NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    NSHTTPCookie* hashCookie = nil; // nomnomnom
    NSHTTPCookie* idCookie = nil;
    NSHTTPCookie* timeCookie = nil;
    
    for (NSHTTPCookie *cookie in [cookieJar cookies]) {
        NSString* name = cookie.name;
        if ([name caseInsensitiveCompare:@"auth[hash]"] == NSOrderedSame)
            hashCookie = cookie;
        else if ([name caseInsensitiveCompare:@"auth[id]"] == NSOrderedSame)
            idCookie = cookie;
        else if ([name caseInsensitiveCompare:@"auth[time]"] == NSOrderedSame)
            timeCookie = cookie;
    }
    
    if (hashCookie && idCookie && timeCookie)
    {
        params[@"v1_auth_hash"] = hashCookie.value;
        params[@"v1_auth_id"] = idCookie.value;
        params[@"v1_auth_time"] = timeCookie.value;
    }
    
    
    ETASDKLogInfo(@"Creating Session...");
    
    [self POST:[ETA_API path:ETA_API.sessions]
    parameters:params
      progress:nil
           success:^(NSURLSessionTask *task, id responseObject) {
               
               // save the sent client ID if we havnt already
               if ([responseObject isKindOfClass:NSDictionary.class])
               {
                   NSString* newClientID = ((NSDictionary*)responseObject)[@"client_id"];
                   if (newClientID && ![self.class clientID])
                       [self.class setClientID:newClientID];
               }
               
               
               if (hashCookie && idCookie && timeCookie)
               {
                   [cookieJar deleteCookie:hashCookie];
                   [cookieJar deleteCookie:idCookie];
                   [cookieJar deleteCookie:timeCookie];
               }
               
               NSError* error = nil;
               ETA_Session* authSession = [ETA_Session objectFromJSONDictionary:responseObject];
               
               // save the session that was created, only if we have created it after any previous requests
               if (authSession)
               {
                   ETASDKLogInfo(@"... Creating Session successful - '%@' => '%@'", self.authSession.token, authSession.token);
                   
                   [self setIfSameOrNewerAuthSession:authSession];
               }
               else
               {
                   //TODO: create error if nil session
                   ETASDKLogWarn(@"... Unable to create session");
               }
               
               
               if (completionHandler)
                   completionHandler(error);
           }
           failure:^(NSURLSessionTask *task, NSError *networkError) {
               if (hashCookie && idCookie && timeCookie)
               {
                   [cookieJar deleteCookie:hashCookie];
                   [cookieJar deleteCookie:idCookie];
                   [cookieJar deleteCookie:timeCookie];
               }
               
               NSError* error = [NSError SGN_errorWithAPIJSONData:networkError.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] urlResponse:task.response] ?: networkError;
               
               
               ETASDKLogWarn(@"... Unable to create session: (%zd) %@ - %@", error.code, error.localizedDescription, error.localizedFailureReason);
               
               
               if (completionHandler)
                   completionHandler(error);
           }];
}

// get the latest state of the session
- (void) updateAuthSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    NSMutableDictionary* params = [[self baseRequestParameters] mutableCopy];
    
    // if we have a client ID send it as a parameter
    NSString* clientID = [self.class clientID];
    if (clientID)
        params[@"client_id"] = clientID;
    
    
    ETASDKLogInfo(@"Updating Session...");
    [self GET:[ETA_API path:ETA_API.sessions]
   parameters:params
     progress:nil
      success:^(NSURLSessionTask *task, id responseObject) {
          
          // save the sent client ID if we havnt already
          if ([responseObject isKindOfClass:NSDictionary.class])
          {
              NSString* newClientID = ((NSDictionary*)responseObject)[@"client_id"];
              if (newClientID && ![self.class clientID])
                  [self.class setClientID:newClientID];
          }
          
          
          NSError* error = nil;
          ETA_Session* authSession = [ETA_Session objectFromJSONDictionary:responseObject];
          
          // save the session that was update, only if we have updated it after any previous requests
          if (authSession)
          {
              ETASDKLogInfo(@"... Updating Session successful - '%@' => '%@'", self.authSession.token, authSession.token);
              [self setIfSameOrNewerAuthSession:authSession];
          }
          else
          {
              //TODO: create error if nil session
              ETASDKLogWarn(@"... Unable to update session");
          }
          
          
          if (completionHandler)
              completionHandler(error);
      }
      failure:^(NSURLSessionTask *task, NSError *networkError) {
          NSError* error = [NSError SGN_errorWithAPIJSONData:networkError.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] urlResponse:task.response] ?: networkError;
          
          ETASDKLogWarn(@"... Unable to update session: (%zd) %@ - %@", error.code, error.localizedDescription, error.localizedFailureReason);
          
          if (completionHandler)
              completionHandler(error);
      }];
}

// Ask for a new expiration date / token
- (void) renewAuthSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    NSMutableDictionary* params = [[self baseRequestParameters] mutableCopy];
    
    // if we have a client ID send it as a parameter
    NSString* clientID = [self.class clientID];
    if (clientID)
        params[@"client_id"] = clientID;
    
    
    ETASDKLogInfo(@"Renewing Session...");
    [self PUT:[ETA_API path:ETA_API.sessions]
       parameters:params
          success:^(NSURLSessionTask *task, id responseObject) {
              
              // save the sent client ID if we havnt already
              if ([responseObject isKindOfClass:NSDictionary.class])
              {
                  NSString* newClientID = ((NSDictionary*)responseObject)[@"client_id"];
                  if (newClientID && ![self.class clientID])
                      [self.class setClientID:newClientID];
              }
              
              
              NSError* error = nil;
              ETA_Session* authSession = [ETA_Session objectFromJSONDictionary:responseObject];

              // save the session that was renewed, only if we have renewed it after any previous requests
              if (authSession)
              {
                  ETASDKLogInfo(@"... Renewing Session successful - '%@' => '%@'", self.authSession.token, authSession.token);
                  [self setIfSameOrNewerAuthSession:authSession];
              }
              else
              {
                  //TODO: create error if nil session
                  ETASDKLogWarn(@"... Unable to renew session");
              }
              
              if (completionHandler)
                  completionHandler(error);
          }
          failure:^(NSURLSessionTask *task, NSError *networkError) {
              NSError* error = [NSError SGN_errorWithAPIJSONData:networkError.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] urlResponse:task.response] ?: networkError;

              ETASDKLogWarn(@"... Unable to renew session: (%zd) %@ - %@", error.code, error.localizedDescription, error.localizedFailureReason);
              
              if (completionHandler)
                  completionHandler(error);
          }];
}



#pragma mark - Session User Management

- (void) attachUser:(NSDictionary*)userCredentials withCompletion:(void (^)(NSError* error))completionHandler
{
    ETASDKLogInfo(@"Attaching User to Session...");
    
    NSMutableDictionary* params =  userCredentials ? [userCredentials mutableCopy] : [NSMutableDictionary dictionary];
    
    // if we have a client ID send it as a parameter
    NSString* clientID = [self.class clientID];
    if (clientID)
        params[@"client_id"] = clientID;
    
    
    [self makeRequest:[ETA_API path:ETA_API.sessions]
                 type:ETARequestTypePUT
           parameters:params
           completion:^(id response, NSError *error) {
               
               ETA_Session* authSession = error ? nil : [ETA_Session objectFromJSONDictionary:response];
               
               // save the session, only if after any previous requests
               if (authSession)
               {
                   ETASDKLogInfo(@"... Attaching User to Session successful - '%@' => '%@'", self.authSession.token, authSession.token);
                   [self setIfSameOrNewerAuthSession:authSession];
               }
               else
               {
                   //TODO: create error if nil session
                   ETASDKLogWarn(@"... Unable to attach user: (%zd) %@ - %@", error.code, error.localizedDescription, error.localizedFailureReason);
               }
               
               if (completionHandler)
                   completionHandler(error);
           }];
}
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler
{
    ETASDKLogInfo(@"Detaching User from Session...");
    
    NSMutableDictionary* params =  [@{ @"email":@"" } mutableCopy];
    
    // if we have a client ID send it as a parameter
    NSString* clientID = [self.class clientID];
    if (clientID)
        params[@"client_id"] = clientID;
    
    [self makeRequest:[ETA_API path:ETA_API.sessions]
                 type:ETARequestTypePUT
           parameters:params
           completion:^(id response, NSError *error) {
               
               ETA_Session* authSession = error ? nil : [ETA_Session objectFromJSONDictionary:response];
               
               // save the session, only if after any previous requests
               if (authSession)
               {
                   ETASDKLogInfo(@"... Detaching User from Session successful - '%@' => '%@'", self.authSession.token, authSession.token);
                   [self setIfSameOrNewerAuthSession:authSession];
               }
               else
               {
                   //TODO: create error if nil session
                   ETASDKLogWarn(@"... Unable to deattach user: (%zd) %@ - %@", error.code, error.localizedDescription, error.localizedFailureReason);
               }
               
               if (completionHandler)
                   completionHandler(error);
           }];
}


- (BOOL) allowsPermission:(NSString*)actionPermission
{
    return [self.authSession allowsPermission:actionPermission];
}

@end
