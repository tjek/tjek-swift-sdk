//
//  ETA_API.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kETAEndpoint_ERNPrefix;                  // eg. "ern:catalog:"
extern NSString* const kETAEndpoint_ItemFilterKey;              // eg. "catalog_id"
extern NSString* const kETAEndpoint_MultipleItemsFilterKey;     // eg. "catalog_ids"
extern NSString* const kETAEndpoint_OtherFilterKeys;            // eg. ["dealer_ids", "store_ids"]
extern NSString* const kETAEndpoint_SortKeys;                   // eg. ["popularity", "name"]
extern NSString* const kETAEndpoint_CacheLifespan;              // eg. 900 secs

extern NSTimeInterval const kETAEndpoint_DefaultCacheLifespan; // in seconds

// A Utility class for getting info about API endpoints
@interface ETA_API : NSObject

#pragma mark - Endpoints

// eg. "catalogs"
+ (NSString*) sessions;
+ (NSString*) catalogs;
+ (NSString*) offers;
+ (NSString*) stores;
+ (NSString*) users;
+ (NSString*) dealers;
+ (NSString*) shoppingLists;
+ (NSString*) shoppingListItems;

#pragma mark - Endpoint properties

+ (NSString*) path:(NSString*)endpoint;
+ (NSString*) pathWithComponents:(NSArray*)components; // eg. "/v2/users/1234/test"

+ (NSArray*) allEndpoints;
+ (BOOL) isValidEndpoint:(NSString*)endpoint;

+ (NSDictionary*) endpointPropertiesByEndpoint;
+ (NSDictionary*) propertiesForEndpoint:(NSString*)endpoint;


#pragma mark - Filter Keys

+ (NSString*) itemFilterKeyForEndpoint:(NSString*)endpoint;
+ (NSString*) multipleItemsFilterKeyForEndpoint:(NSString*)endpoint;
+ (NSArray*) allFilterKeysForEndpoint:(NSString*)endpoint;


#pragma mark - ERN

+ (NSString*) ernPrefixForEndpoint:(NSString*)endpoint;
+ (NSString*) ernForEndpoint:(NSString*)endpoint withItemID:(NSString*)itemID;

#pragma mark - Cache

+ (NSTimeInterval) cacheLifespanForEndpoint:(NSString*)endpoint; //invalid endpoint results in default lifespan
+ (NSTimeInterval) maxCacheLifespan; // the largest lifespan of all the endpoints

#pragma mark - Utilities

+ (NSDateFormatter *)dateFormatter;

@end
