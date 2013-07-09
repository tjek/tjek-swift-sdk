//
//  ETA.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ETA_APIClient.h"

@interface ETA : NSObject

@property (nonatomic, readonly, strong) NSString *apiKey;
@property (nonatomic, readonly, strong) NSString *apiSecret;
@property (nonatomic, readonly, assign, getter=isConnected) BOOL connected;


+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret;

- (void) connect:(void (^)(NSError* error))completionHandler;
- (void) connectWithUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(BOOL connected, NSError* error))completionHandler;

- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler;
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler;

- (void) makeRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(NSDictionary* response, NSError* error))completionHandler;

@end


@interface ETA (Catalogs)

- (void) getCatalogsWithCatalogIDs:(NSArray*)catalogIDs
                         dealerIDs:(NSArray*)dealerIDs
                          storeIDs:(NSArray*)storeIDs
                           orderBy:(NSArray*)sortKeys
                             limit:(NSUInteger)limit offset:(NSUInteger)offset
                        completion:(void (^)(NSArray* catalogs, NSError* error))completionHandler;

@end