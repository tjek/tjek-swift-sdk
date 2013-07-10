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




#pragma mark - Connecting

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




#pragma mark - User Management

- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler
{
    [self.client attachUser:@{@"email":email, @"password":password} withCompletion:completionHandler];
}
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self.client detachUserWithCompletion:completionHandler];
}




#pragma mark - Sending API Requests

// the parameters that are derived from the client, that may be overridded by the request
- (NSDictionary*) baseRequestParameters
{
    NSMutableDictionary* params = [@{} mutableCopy];
    [params addEntriesFromDictionary:[self geolocationParameters]];
    
    return params;
}


- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(NSDictionary* response, NSError* error))completionHandler
{
    //TODO: Real error
    if (!self.isConnected)
        completionHandler(nil, [NSError errorWithDomain:@"" code:0 userInfo:nil]);
    
    // get the base parameters, and override them with those passed in
    NSMutableDictionary* mergedParameters = [[self baseRequestParameters] mutableCopy];
    [mergedParameters setValuesForKeysWithDictionary:parameters];
    

    [self.client makeRequest:requestPath type:type parameters:parameters completion:completionHandler];
}




#pragma mark - Geolocation

+ (NSArray*) preferredDistances
{
    return @[ @100, @150, @200, @250, @300, @350,
              @400, @450, @500, @600, @700, @800,
              @900, @1000, @1500, @2000, @2500,
              @3000, @3500, @4000, @4500, @5000,
              @5500, @6000, @6500, @7000, @7500,
              @8000, @8500, @9000, @9500, @10000,
              @15000, @20000, @25000, @30000, @35000,
              @40000, @45000, @50000, @55000, @60000,
              @65000, @70000, @75000, @80000, @85000,
              @90000, @95000, @100000, @200000, @300000,
              @400000, @500000, @600000, @700000 ];
}

- (NSDictionary*) geolocationParameters
{
    NSMutableDictionary* params = [@{} mutableCopy];
    if (self.location)
    {
        params[@"r_lat"] = @(self.location.coordinate.latitude);
        params[@"r_lng"] = @(self.location.coordinate.longitude);
        
        if (self.distance)
        {
            NSArray* dists = [[self class] preferredDistances];
            CGFloat minDistance = [dists[0] floatValue];
            CGFloat maxDistance = [[dists lastObject] floatValue];
            
            CGFloat clampedDistance = MIN(MAX(self.distance.floatValue, minDistance), maxDistance);
            params[@"r_radius"] = @(clampedDistance);
        }
    }
    
    return params;
}

- (void) setLatitude:(CGFloat)latitude longitude:(CGFloat)longitude distance:(CGFloat)distance isFromSensor:(BOOL)isFromSensor
{
    self.location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    self.distance = @(distance);
    self.isLocationFromSensor = isFromSensor;
}

@end
