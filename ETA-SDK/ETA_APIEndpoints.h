//
//  ETA_APIEndpoints.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kETAEndpoint_ShortName;                  // eg. "catalog"
extern NSString* const kETAEndpoint_ERNPrefix;                  // eg. "ern:catalog:"
extern NSString* const kETAEndpoint_ItemFilterKey;              // eg. "catalog_id"
extern NSString* const kETAEndpoint_MultipleItemsFilterKey;     // eg. "catalog_ids"
extern NSString* const kETAEndpoint_OtherFilterKeys;            // eg. ["dealer_ids", "store_ids"]
extern NSString* const kETAEndpoint_SortKeys;                   // eg. ["popularity", "name"]
extern NSString* const kETAEndpoint_CacheLifespan;              // eg. 900 secs

extern NSTimeInterval const kETAEndpoint_DefaultCacheLifespan; // in seconds

@interface ETA_APIEndpoints : NSObject

#pragma mark - Endpoints

// eg. "/v2/catalogs"
+ (NSString*) sessions;
+ (NSString*) catalogs;


#pragma mark - Endpoint properties

+ (NSArray*) allEndpoints;

+ (NSDictionary*) endpointPropertiesByEndpoint;
+ (NSDictionary*) endpointsByShortName;
+ (NSDictionary*) propertiesForEndpoint:(NSString*)endpoint;
+ (NSString*) endpointForShortName:(NSString*)shortName;


#pragma mark - Filter Keys

+ (NSString*) itemFilterKeyForEndpoint:(NSString*)endpoint;
+ (NSString*) multipleItemsFilterKeyForEndpoint:(NSString*)endpoint;
+ (NSArray*) allFilterKeysForEndpoint:(NSString*)endpoint;


#pragma mark - ERN

+ (NSString*) ernPrefixForEndpoint:(NSString*)endpoint;
+ (NSString*) ernForEndpoint:(NSString*)endpoint withItemID:(NSString*)itemID;

#pragma mark - Cache

+ (NSTimeInterval) cacheLifespanForEndpoint:(NSString*)endpoint; //invalid endpoint results in default lifespan

@end
