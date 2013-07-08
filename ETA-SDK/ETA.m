//
//  ETA.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA.h"

#import "ETA_Session.h"
#import "ETA_APIClient.h"

#import "AFNetworking.h"

@implementation ETA
+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret
{
    ETA* eta = [[ETA alloc] init];
    
    eta.apiKey = apiKey;
    eta.apiSecret = apiSecret;

    return eta;
}

- (id) init
{
    if ((self = [super init]))
    {
        
    }
    return self;
}

- (void) connect:(void (^)(NSError* error))callback
{
    // First try to get stored state of the session
    
    ETA_APIClient * client = [ETA_APIClient clientWithApiKey:self.apiKey apiSecret:self.apiSecret];
    
    
    
//    ETASession* session = [ETASession sessionWithToken:];
    
    // if token exists, check the expiration date
    
    // if almost out of date, try to renew the token
    
    // if there is no valid token, put a
    
}

- (void) updateSession
{
    
}

@end
