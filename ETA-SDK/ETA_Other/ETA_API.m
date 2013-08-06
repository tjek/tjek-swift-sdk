//
//  ETA_API.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_API.h"

NSString* const kETAEndpoint_ERNPrefix = @"kETAEndpoint_ERNPrefix";
NSString* const kETAEndpoint_ItemFilterKey = @"kETAEndpoint_ItemFilterKey";
NSString* const kETAEndpoint_MultipleItemsFilterKey = @"kETAEndpoint_MultipleItemsFilterKey";
NSString* const kETAEndpoint_OtherFilterKeys = @"kETAEndpoint_OtherFilterKeys";
NSString* const kETAEndpoint_SortKeys = @"kETAEndpoint_SortKeys";
NSString* const kETAEndpoint_CacheLifespan = @"kETAEndpoint_CacheLifespan";

NSTimeInterval const kETAEndpoint_DefaultCacheLifespan = 900; //15 mins

@implementation ETA_API

#pragma mark - Endpoints

+ (NSString*) sessions  {   return @"sessions"; }
+ (NSString*) catalogs  {   return @"catalogs"; }
+ (NSString*) offers    {   return @"offers"; }
+ (NSString*) stores    {   return @"stores"; }
+ (NSString*) users     {   return @"users"; }
+ (NSString*) dealers   {   return @"dealers"; }
+ (NSString*) shoppingLists     {   return @"shoppinglists"; }
+ (NSString*) shoppingListItems {   return @"items"; }
#pragma mark - Properties

+ (NSDictionary*) endpointPropertiesByEndpoint
{
    static NSDictionary* endpointProperties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        endpointProperties =  @{
                                self.sessions: @{},
                                self.catalogs: @{
                                        kETAEndpoint_ERNPrefix:                 @"ern:catalog:",
                                        kETAEndpoint_ItemFilterKey:             @"catalog_id",
                                        kETAEndpoint_MultipleItemsFilterKey:    @"catalog_ids",
                                        kETAEndpoint_OtherFilterKeys:           @[  @"dealer_ids",
                                                                                    @"store_ids",
                                                                                ],
                                        kETAEndpoint_SortKeys:                  @[  @"popularity",
                                                                                    @"name",
                                                                                    @"published",
                                                                                    @"expires",
                                                                                    @"created",
                                                                                    @"distance",
                                                                                ],
                                        },
                                self.offers: @{
                                        kETAEndpoint_ERNPrefix:                 @"ern:offer:",
                                        kETAEndpoint_ItemFilterKey:             @"offer_id",
                                        kETAEndpoint_MultipleItemsFilterKey:    @"offer_ids",
                                        kETAEndpoint_OtherFilterKeys:           @[  @"catalog_ids",
                                                                                    @"dealer_ids",
                                                                                    @"store_ids",
                                                                                    ],
                                        kETAEndpoint_SortKeys:                  @[  @"popularity",
                                                                                    @"page",
                                                                                    @"created",
                                                                                    @"distance",
                                                                                    @"price",
                                                                                    @"quantity",
                                                                                    @"count",
                                                                                    @"expiration_date",
                                                                                    @"publication_date",
                                                                                    @"valid_date",
                                                                                    @"dealer",
                                                                                    ],

                                        },
                                self.stores: @{
                                        kETAEndpoint_ERNPrefix: @"ern:store:",
                                        },
                                self.users: @{
                                        kETAEndpoint_ERNPrefix: @"ern:user:",
                                        },
                                self.dealers: @{
                                        kETAEndpoint_ERNPrefix: @"ern:dealer:",
                                        },
                                self.shoppingLists: @{
                                        kETAEndpoint_ERNPrefix: @"ern:shopping:list:",
                                        },
                                self.shoppingListItems: @{
                                        kETAEndpoint_ERNPrefix: @"ern:shopping:item:",
                                        },
                                };
    });
    return endpointProperties;
}

+ (NSString*) path:(NSString*)endpoint
{
    if (endpoint)
        return [self pathWithComponents:@[endpoint]];
    else
        return nil;
}
+ (NSString*) pathWithComponents:(NSArray*)components
{
    if (!components)
        return nil;
    else
        return [@"/v2/" stringByAppendingPathComponent:[NSString pathWithComponents:components]];
}
+ (NSArray*) allEndpoints
{
    static NSArray* allEndpoints = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allEndpoints = [self.endpointPropertiesByEndpoint allKeys];
    });
    return allEndpoints;
}

+ (BOOL) isValidEndpoint:(NSString*)endpoint
{
    return endpoint && [self.allEndpoints containsObject:endpoint];
}

+ (NSDictionary*) propertiesForEndpoint:(NSString*)endpoint
{
    if (!endpoint)
        return nil;
    return self.endpointPropertiesByEndpoint[endpoint];
}



#pragma mark - Filter Keys

+ (NSArray*) itemFilterKeyForEndpoint:(NSString*)endpoint
{
    return [self propertiesForEndpoint:endpoint][kETAEndpoint_ItemFilterKey];
}

+ (NSString*) multipleItemsFilterKeyForEndpoint:(NSString*)endpoint
{
    return [self propertiesForEndpoint:endpoint][kETAEndpoint_MultipleItemsFilterKey];
}
+ (NSArray*) allFilterKeysForEndpoint:(NSString*)endpoint
{
    NSDictionary* props = [self propertiesForEndpoint:endpoint];
    NSMutableArray* filterKeys = [@[] mutableCopy];
    
    id key = nil;
    if ( (key = props[kETAEndpoint_ItemFilterKey]) )
        [filterKeys addObject:key];
    if ( (key = props[kETAEndpoint_MultipleItemsFilterKey]) )
        [filterKeys addObject:key];
    if ( (key = props[kETAEndpoint_OtherFilterKeys]) )
        [filterKeys addObjectsFromArray:key];
    
    return filterKeys;
}


#pragma mark - ERN

+ (NSString*) ernPrefixForEndpoint:(NSString*)endpoint
{
    return [self propertiesForEndpoint:endpoint][kETAEndpoint_ERNPrefix];
}
+ (NSString*) ernForEndpoint:(NSString*)endpoint withItemID:(NSString*)itemID
{
    if (!endpoint || !itemID.length)
        return nil;
    NSString* prefix = [self ernPrefixForEndpoint:endpoint];
    return (prefix) ? [NSString stringWithFormat:@"%@%@", prefix, itemID] : nil;
}


#pragma mark - Cache

+ (NSTimeInterval) maxCacheLifespan
{
    static NSTimeInterval maxCacheLifespan;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSTimeInterval lifespan = 0;
        for (NSString* endpoint in [self allEndpoints])
        {
            lifespan = MAX(lifespan, [self cacheLifespanForEndpoint:endpoint]);
        }
        maxCacheLifespan = lifespan;
    });
    return maxCacheLifespan;
}

+ (NSTimeInterval) cacheLifespanForEndpoint:(NSString*)endpoint
{
    NSNumber* lifespan = [self propertiesForEndpoint:endpoint][kETAEndpoint_CacheLifespan];
    if (!lifespan)
        return kETAEndpoint_DefaultCacheLifespan;
    else
        return lifespan.doubleValue;
}


#pragma mark - Utilities

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZ";
        
    });
    return dateFormatter;
}

@end
