//
//  ETA_APIClient.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_APIClient.h"

#import "ETA_Session.h"

#import "AFJSONRequestOperation.h"

#import "NSString+SHA256Digest.h"

static NSString* const kETA_SessionUserDefaultsKey = @"ETA_Session";

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
    
    [client setupSession];
    return client;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if ((self = [super initWithBaseURL:url]))
    {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        
        [self setDefaultHeader:@"Accept" value:@"application/json"];
    }
    return self;
}


#pragma mark - Session Management

- (void) setupSession
{
    // try to get the session from user defaults
    [self loadSessionFromStorage];
    
    // no session stored, create one from scratch
    if (!self.session)
    {
        [self createSession];
    }
}

// get the session from UserDefaults
- (void) loadSessionFromStorage
{
    NSString* sessionJSON = [[NSUserDefaults standardUserDefaults] valueForKey:kETA_SessionUserDefaultsKey];
    NSDictionary* sessionDict = (sessionJSON) ? [NSJSONSerialization JSONObjectWithData:[sessionJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    
    ETA_Session* session = nil;
    if (sessionDict)
    {
        NSError* err = nil;
        session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:sessionDict error:&err];
//        session = [[ETA_Session alloc] initWithDictionary:sessionDict error:&err];
        if (session)
            self.session = session;
    }
}

- (void) saveSessionToStorage
{
    NSDictionary* sessionDict = [MTLJSONAdapter JSONDictionaryFromModel:self.session];
    NSString* sessionJSON = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:sessionDict options:0 error:nil]
                                                  encoding: NSUTF8StringEncoding];
    
    [[NSUserDefaults standardUserDefaults] setObject: sessionJSON
                                              forKey:kETA_SessionUserDefaultsKey];
}
    
// create a new session, and assign
- (void) createSession
{
    [self postPath:@"/v2/sessions"
        parameters: @{ @"api_key": (self.apiKey) ?: [NSNull null] }
           success:^(AFHTTPRequestOperation *operation, id responseObject) {
               NSError* err = nil;
               ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:responseObject error:&err];               
               if (session)
               {
                   self.session = session;
               }
           }
           failure:^(AFHTTPRequestOperation *operation, NSError *error) {
               DLog(@"Couldnt Create: %@", error);
           }];
}

// get the latest state of the session
- (void) updateSession
{
    [self putPath:@"/v2/sessions"
       parameters:nil
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              NSError* err = nil;
              ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:responseObject error:&err];
              if (session)
              {
                  [self.session mergeValuesForKeysFromModel:session];
                  
                  [self sessionDidChange];
              }
          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              DLog(@"Couldnt Update: %@", error);
          }];
}

// Ask for a new expiration date
- (void) renewSession
{
    [self getPath:@"/v2/sessions"
       parameters:nil
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              NSError* err = nil;
              ETA_Session* session = [MTLJSONAdapter modelOfClass:[ETA_Session class] fromJSONDictionary:responseObject error:&err];
              if (session)
              {
                  [self.session mergeValuesForKeysFromModel:session];
                  
                  [self sessionDidChange];
              }
          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              DLog(@"Couldnt Renew: %@", error);
          }];
}

- (void) sessionDidChange
{
    [self updateHeaders];
    [self saveSessionToStorage];
}

#pragma mark - Setters

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

- (void) setApiKey:(NSString *)apiKey
{
    _apiKey = apiKey;
}

- (void) setApiSecret:(NSString *)apiSecret
{
    _apiSecret = apiSecret;
    
    [self updateHeaders];
}

- (void) setSession:(ETA_Session *)session
{
    _session = session;
    
    [self sessionDidChange];
    
    // if the session is out of date, renew it
    if ([self.session willExpireSoon])
    {
        [self renewSession];
    }
    // otherwise, update it
    else
    {
        [self updateSession];
    }
}

@end
