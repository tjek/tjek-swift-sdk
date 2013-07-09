//
//  ETA.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA.h"

#import "ETA_APIClient.h"

#import "AFNetworking.h"

//NSString* const kETA_APIPath_Catalogs = @"/v2/catalogs";
//NSString* const kETA_APIPath_Offers = @"/v2/offers";
//NSString* const kETA_APIPath_Stores = @"/v2/stores";
//NSString* const kETA_APIPath_Users = @"/v2/catalogs";
//NSString* const kETA_APIPath_Dealers = @"/v2/dealers";
//NSString* const kETA_APIPath_Apps = @"/v2/catalogs";
//NSString* const kETA_APIPath_Groups = @"/v2/catalogs";
//NSString* const kETA_APIPath_Permissions = @"/v2/admin/auth/permissions";
//NSString* const kETA_APIPath_ShoppingLists = @"/v2/shoppinglists";


@interface ETA ()
@property (nonatomic, readwrite, strong) ETA_APIClient* client;

@property (nonatomic, readwrite, strong) NSString *apiKey;
@property (nonatomic, readwrite, strong) NSString *apiSecret;
@property (nonatomic, readwrite, assign) BOOL connected;
@end

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
        _connected = NO;
    }
    return self;
}

- (void) connect:(void (^)(NSError* error))completionHandler
{
    self.connected = NO;
    
    // First try to get stored state of the session
    self.client = [ETA_APIClient clientWithApiKey:self.apiKey apiSecret:self.apiSecret];
    
    [self.client startSessionWithCompletion:^(NSError *error) {
        self.connected = !error;
        completionHandler(error);
    }];
}
- (void) connectWithUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(BOOL connected, NSError* error))completionHandler
{
    [self connect:^(NSError *error) {
        if (!error)
        {
            [self attachUserEmail:email password:password completion:^(NSError *error) {
                completionHandler(YES, error);
            }];
        } else {
            completionHandler(NO, error);
        }
    }];
}
- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler
{
    [self.client attachUser:@{@"email":email, @"password":password} withCompletion:completionHandler];
}
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self.client detachUserWithCompletion:completionHandler];
}

- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(NSDictionary* response, NSError* error))completionHandler
{
    if (!self.isConnected)
        completionHandler(nil, [NSError errorWithDomain:@"" code:0 userInfo:nil]);
    
    [self.client makeRequest:requestPath type:type parameters:parameters completion:completionHandler];
}


@end
