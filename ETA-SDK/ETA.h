//
//  ETA.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "ETA_APIClient.h"

@interface ETA : NSObject


@property (nonatomic, readonly, strong) NSString *apiKey;
@property (nonatomic, readonly, strong) NSString *apiSecret;

@property (nonatomic, readonly, assign, getter=isConnected) BOOL connected;


+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret;


#pragma mark - Connecting

- (void) connect:(void (^)(NSError* error))completionHandler;
- (void) connectWithUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(BOOL connected, NSError* error))completionHandler;


#pragma mark - User Management

- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler;
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler;


#pragma mark - Sending API Requests

- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(NSDictionary* response, NSError* error))completionHandler;


#pragma - Geolocation

// Any changes to location will be applied to all future requests.
// There will be no location info sent by default.
// Distance will only be sent if there is also a location to send.
@property (nonatomic, readwrite, strong) CLLocation* location;
@property (nonatomic, readwrite, assign) NSNumber* distance; // meters

// 'isLocationFromSensor' is currently just metadata for the server.
// Set to YES if the location property comes from the device's sensor.
@property (nonatomic, readwrite, assign) BOOL isLocationFromSensor;

// A utility geolocation setter method
- (void) setLatitude:(CGFloat)latitude longitude:(CGFloat)longitude distance:(CGFloat)distance isFromSensor:(BOOL)isFromSensor;

// A list of the distances that we prefer to use.
// The 'distance' property will be clamped to within these numbers before being sent
+ (NSArray*) preferredDistances;




@end

@interface ETA (Catalogs)

- (void) getCatalogsWithCatalogIDs:(NSArray*)catalogIDs
                         dealerIDs:(NSArray*)dealerIDs
                          storeIDs:(NSArray*)storeIDs
                           orderBy:(NSArray*)sortKeys
                             limit:(NSUInteger)limit offset:(NSUInteger)offset
                        completion:(void (^)(NSArray* catalogs, NSError* error))completionHandler;

@end