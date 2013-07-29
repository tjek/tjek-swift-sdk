//
//  ETA_APIClient.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_APIClient.h"

#import "ETA.h"
#import "ETA_Session.h"
#import "ETA_API.h"

#import "NSValueTransformer+ETAPredefinedValueTransformers.h"

#import "AFJSONRequestOperation.h"

#import "NSString+SHA256Digest.h"

static NSString* const kETA_SessionUserDefaultsKey = @"ETA_Session";


NSString* const ETA_APIErrorDomain = @"ETA_APIErrorDomain";
NSString* const ETA_APIError_URLResponseKey = @"ETA_APIError_URLResponseKey";
NSString* const ETA_APIError_ErrorIDKey = @"ETA_APIError_IDKey";


@interface ETA_APIClient ()

@property (nonatomic, readwrite, strong) NSString *apiKey;
@property (nonatomic, readwrite, strong) NSString *apiSecret;

@end


@implementation ETA_APIClient
{
    dispatch_semaphore_t _startingSessionLock;
    dispatch_queue_t _syncQueue;
}


#pragma mark - Constructors

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
        _syncQueue = dispatch_queue_create("com.eTilbudsAvis.ETA_APIClient.syncQ", 0);
        
        _startingSessionLock = dispatch_semaphore_create(1);
        
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        
        [self setDefaultHeader:@"Accept" value:@"application/json"];
        
        self.storageEnabled = YES;
    }
    return self;
}



#pragma mark - API Requests

// the parameters that are derived from the client, that may be overridded by the request
- (NSDictionary*) baseRequestParameters
{
    return @{};
}

// send a request, and on sucessful response update the session token, if newer
- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(id JSONResponse, NSError* error))completionHandler
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
            
            
            void (^successBlock)(AFHTTPRequestOperation*, id) = ^(AFHTTPRequestOperation *operation, id responseObject)
            {
                
                [self updateSessionTokenFromHeaders:operation.response.allHeaderFields];
                if (completionHandler)
                    completionHandler(responseObject, nil);
            };
            void (^failureBlock)(AFHTTPRequestOperation*, id) = ^(AFHTTPRequestOperation *operation, NSError *error)
            {
                NSError* etaError = [[self class] etaErrorFromAFNetworkingError:error];
                
                if (completionHandler)
                    completionHandler(nil, (etaError) ?: error);
            };
            
            switch (type)
            {
                case ETARequestTypeGET:
                    [self getPath:requestPath parameters:cleanedParameters success:successBlock failure:failureBlock];
                    break;
                case ETARequestTypePOST:
                    [self postPath:requestPath parameters:cleanedParameters success:successBlock failure:failureBlock];
                    break;
                case ETARequestTypePUT:
                    [self putPath:requestPath parameters:cleanedParameters success:successBlock failure:failureBlock];
                    break;
                case ETARequestTypeDELETE:
                    [self deletePath:requestPath parameters:cleanedParameters success:successBlock failure:failureBlock];
                    break;
                default:
                    break;
            }
        };
        
        // the session hasnt been created, or it failed when previously created
        // try to create the session from scratch.
        // we are currently on the syncQ, so dont syncronously dispatch the start to the syncQ
        if (!self.session)
        {
            [self startSessionOnSyncQueue:NO withCompletion:^(NSError *error) {
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
    if (self.session.token && self.apiSecret)
    {
        hash = [[NSString stringWithFormat:@"%@%@", self.apiSecret, self.session.token] SHA256HexDigest];
    }
//    DLog(@"[CLIENT] Updating Headers - Token:'%@'->'%@' Sig:'%@'->'%@'", [self defaultValueForHeader:@"X-Token"], self.session.token, [self defaultValueForHeader:@"X-Signature"], hash);
    
    [self setDefaultHeader:@"X-Token"       value:self.session.token];
    [self setDefaultHeader:@"X-Signature"   value:hash];
}




#pragma mark - Session Setters

- (void) setIfSameOrNewerSession:(ETA_Session *)session
{
    if ([session isExpiryTheSameAsSession:self.session] ||
        [session isExpiryNewerThanSession:self.session])
    {
        self.session = session;
    }
}
- (void) setIfNewerSession:(ETA_Session *)session
{
    if ([session isExpiryNewerThanSession:self.session])
    {
        self.session = session;
    }
}


// Setting the session causes the change to be persisted to User Defaults
- (void) setSession:(ETA_Session *)session
{
    DLog(@"[CLIENT] Setting Session '%@' (%@) => '%@' (%@)", _session.token, _session.expires, session.token, session.expires);
    
    _session = session;
    [self updateHeaders];
    [self saveSessionToStorage];
}

// This will only update the session token/expiry if the expiry is newer
- (void) updateSessionTokenFromHeaders:(NSDictionary*)headers
{
    NSString* newToken = headers[@"X-Token"];
    
    NSDate* newExpiryDate = [ETA_API.dateFormatter dateFromString:headers[@"X-Token-Expires"]];
    
    if (!newExpiryDate || !newToken)
        return;
    
    // check if it would change anything about the session.
    // if the tokens are the same and the new date is not newer then it's a no-op
    if ([self.session.token isEqualToString:newToken])
        return;
    if (self.session.expires && [newExpiryDate compare: self.session.expires]!=NSOrderedDescending)
        return;
        
    // merge the expiry/token with the current session
    ETA_Session* newSession = [self.session copy];
    [newSession setValuesForKeysWithDictionary:@{@"token":newToken,
                                                 @"expires":newExpiryDate}];
    
//    DLog(@"[SESSION] Updating Session Tokens - '%@' (%@) => '%@' (%@)", self.session.token, self.session.expires, newSession.token, newSession.expires);
    self.session = newSession;
}

#pragma mark - Session Loading / Updating / Saving

// get the session, either from local storage or creating a new one, and make sure it's up to date
// it will perform it on the sync queue
- (void) startSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self startSessionOnSyncQueue:YES withCompletion:completionHandler];
}

- (void) startSessionOnSyncQueue:(BOOL)dispatchOnSyncQ withCompletion:(void (^)(NSError* error))completionHandler
{
    // do it on the sync queue, and block until the completion occurs - that way any other requests will have to wait for the session to have started
    void (^block)() = ^{
        // previous connect was sucessful - dont bother connecting (and dont block syncQ with completion handler
        if (self.session)
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
        [self loadSessionFromStorage];
        
        // if there is no session, or either renew or update fail, call this block, which tries to create a new session
        void (^createSessionBlock)() = ^{
            DLog(@"[SESSION] Resetting before creating - '%@' => '%@'", self.session.token, nil);
            self.session = nil;
            [self createSessionWithCompletion:^(NSError *error) {
                if (error)
                {
                    DLog(@"Unable to create session. Now what?");
                }
                dispatch_semaphore_signal(sema); // tell the syncQueue block to finish
                if (completionHandler)
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
                    {
                        dispatch_semaphore_signal(sema); // tell the syncQueue block to finish
                        if (completionHandler)
                            completionHandler(error);
                    }
                }];
            }
            // otherwise, update it
            else
            {
                [self updateSessionWithCompletion:^(NSError *error) {
                    if (error)
                    {
                        DLog(@"Unable to update session - trying to create a new one instead: %@", error.localizedDescription);
                        createSessionBlock();
                    }
                    else
                    {
                        dispatch_semaphore_signal(sema); // tell the syncQueue block to finish
                        if (completionHandler)
                            completionHandler(error);
                    }
                }];
            }
        }
        // no previous session exists - create a new one
        else
        {
            createSessionBlock(nil);
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
- (void) loadSessionFromStorage
{
    if (!self.storageEnabled)
        return;
    
    NSString* sessionJSON = [[NSUserDefaults standardUserDefaults] valueForKey:kETA_SessionUserDefaultsKey];
    NSDictionary* sessionDict = (sessionJSON) ? [NSJSONSerialization JSONObjectWithData:[sessionJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    ETA_Session* session = nil;
    if (sessionDict)
    {
        session = [ETA_Session objectFromJSONDictionary:sessionDict];
    }
    
    DLog(@"[SESSION] Loading Session - '%@' => '%@'", self.session.token, session.token);
    self.session = session;
}

// save the session to local storage
- (void) saveSessionToStorage
{
    if (!self.storageEnabled)
        return;
    
    NSString* sessionJSON = nil;
    if (self.session)
    {
        NSDictionary* sessionDict = [self.session JSONDictionary];
        
        sessionJSON = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:sessionDict options:0 error:nil]
                                            encoding: NSUTF8StringEncoding];
    }
    [[NSUserDefaults standardUserDefaults] setObject: sessionJSON
                                              forKey:kETA_SessionUserDefaultsKey];
}
    
// create a new session, and assign
- (void) createSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self postPath:[ETA_API path:ETA_API.sessions]
        parameters:@{ @"api_key": (self.apiKey) ?: [NSNull null] }
           success:^(AFHTTPRequestOperation *operation, id responseObject) {
               NSError* error = nil;
               ETA_Session* session = [ETA_Session objectFromJSONDictionary:responseObject];
               
               // save the session that was created, only if we have created it after any previous requests
               if (session)
               {
                   DLog(@"[SESSION] Creating Session - '%@' => '%@'", self.session.token, session.token);
                   
                   [self setIfSameOrNewerSession:session];
               }
               //TODO: create error if nil session
               
               if (completionHandler)
                   completionHandler(error);
           }
           failure:^(AFHTTPRequestOperation *operation, NSError *error) {
               NSError* etaError = [[self class] etaErrorFromAFNetworkingError:error];
               
               if (completionHandler)
                   completionHandler((etaError) ?: error);
           }];
}

// get the latest state of the session
- (void) updateSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self getPath:[ETA_API path:ETA_API.sessions]
       parameters:nil
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              NSError* error = nil;
              ETA_Session* session = [ETA_Session objectFromJSONDictionary:responseObject];

              // save the session that was update, only if we have updated it after any previous requests
              if (session)
              {
                  DLog(@"[SESSION] Updating Session - '%@' => '%@'", self.session.token, session.token);
                  [self setIfSameOrNewerSession:session];
              }
              //TODO: create error if nil session
              
              if (completionHandler)
                  completionHandler(error);
           }
           failure:^(AFHTTPRequestOperation *operation, NSError *error) {
               NSError* etaError = [[self class] etaErrorFromAFNetworkingError:error];
               
               if (completionHandler)
                   completionHandler((etaError) ?: error);
           }];
}

// Ask for a new expiration date / token
- (void) renewSessionWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self putPath:[ETA_API path:ETA_API.sessions]
       parameters:nil
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              NSError* error = nil;
              ETA_Session* session = [ETA_Session objectFromJSONDictionary:responseObject];

              // save the session that was renewed, only if we have renewed it after any previous requests
              if (session)
              {
                  DLog(@"[SESSION] Renewing Session - '%@' => '%@'", self.session.token, session.token);
                  [self setIfSameOrNewerSession:session];
              }
              //TODO: create error if nil session
              
              if (completionHandler)
                  completionHandler(error);
          }
          failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              NSError* etaError = [[self class] etaErrorFromAFNetworkingError:error];
              
              if (completionHandler)
                  completionHandler((etaError) ?: error);
          }];
}



#pragma mark - Session User Management

- (void) attachUser:(NSDictionary*)userCredentials withCompletion:(void (^)(NSError* error))completionHandler
{
    [self makeRequest:[ETA_API path:ETA_API.sessions]
                 type:ETARequestTypePUT
           parameters:userCredentials
           completion:^(id response, NSError *error) {
               
               error = ([[self class] etaErrorFromAFNetworkingError:error]) ?: error;
               
               ETA_Session* session = [ETA_Session objectFromJSONDictionary:response];
               
               // save the session, only if after any previous requests
               if (session)
               {
                   DLog(@"[SESSION] Attaching User to Session - '%@' => '%@'", self.session.token, session.token);
                   [self setIfSameOrNewerSession:session];
               }
               //TODO: create error if nil session
               
               if (completionHandler)
                   completionHandler(error);
           }];
}
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self makeRequest:[ETA_API path:ETA_API.sessions]
                 type:ETARequestTypePUT
           parameters:@{ @"email":@"" }
           completion:^(id response, NSError *error) {
               
               error = ([[self class] etaErrorFromAFNetworkingError:error]) ?: error;
               
               ETA_Session* session = [ETA_Session objectFromJSONDictionary:response];
               
               // save the session, only if after any previous requests
               if (session)
               {
                   DLog(@"[SESSION] Detaching User from Session - '%@' => '%@'", self.session.token, session.token);
                   [self setIfSameOrNewerSession:session];
               }
               //TODO: create error if nil session
               
               if (completionHandler)
                   completionHandler(error);
           }];
}


- (BOOL) allowsPermission:(NSString*)actionPermission
{
    return [self.session allowsPermission:actionPermission];
}



+ (NSError*) etaErrorFromAFNetworkingError:(NSError*)AFNetworkingError
{
    NSDictionary* etaErrorDict = nil;
    NSString* errorDesc = AFNetworkingError.userInfo[NSLocalizedRecoverySuggestionErrorKey];
    if (errorDesc)
        etaErrorDict = [NSJSONSerialization JSONObjectWithData:[errorDesc dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    if (!etaErrorDict)
        return nil;
    
    NSString* errCode = etaErrorDict[@"code"];
    if (!errCode)
        return nil;
    
    NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
    
    [userInfo setValue:etaErrorDict[@"message"] forKey:NSLocalizedDescriptionKey];
    [userInfo setValue:etaErrorDict[@"details"] forKey:NSLocalizedFailureReasonErrorKey];
    [userInfo setValue:etaErrorDict[@"@note.1"] forKey:NSLocalizedRecoverySuggestionErrorKey];
    [userInfo setValue:etaErrorDict[@"id"] forKey:ETA_APIError_ErrorIDKey];
    [userInfo setValue:AFNetworkingError.userInfo[AFNetworkingOperationFailingURLResponseErrorKey] forKey:ETA_APIError_URLResponseKey];
    
    return [NSError errorWithDomain:ETA_APIErrorDomain code:errCode.integerValue userInfo:userInfo];
}


@end
