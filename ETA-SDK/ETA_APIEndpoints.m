//
//  ETA_APIEndpoints.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_APIEndpoints.h"

NSString* const kETAEndpoint_ShortName = @"kETAEndpoint_ShortName";
NSString* const kETAEndpoint_ERNPrefix = @"kETAEndpoint_ERNPrefix";
NSString* const kETAEndpoint_ItemFilterKey = @"kETAEndpoint_ItemFilterKey";
NSString* const kETAEndpoint_MultipleItemsFilterKey = @"kETAEndpoint_MultipleItemsFilterKey";
NSString* const kETAEndpoint_OtherFilterKeys = @"kETAEndpoint_OtherFilterKeys";
NSString* const kETAEndpoint_SortKeys = @"kETAEndpoint_SortKeys";
NSString* const kETAEndpoint_CacheLifespan = @"kETAEndpoint_CacheLifespan";

NSTimeInterval const kETAEndpoint_DefaultCacheLifespan = 900; //15 mins

@implementation ETA_APIEndpoints

#pragma mark - Endpoints

+ (NSString*) sessions  {   return @"/v2/sessions"; }
+ (NSString*) catalogs  {   return @"/v2/catalogs"; }

#pragma mark - Properties

+ (NSDictionary*) endpointPropertiesByEndpoint
{
    static NSDictionary* endpointProperties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        endpointProperties =  @{
                                self.sessions: @{},
                                self.catalogs: @{
                                        kETAEndpoint_ShortName:                 @"catalogs",
                                        kETAEndpoint_ERNPrefix:                 @"ern:catalog:",
                                        kETAEndpoint_CacheLifespan:             @12,
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
                                };
    });
    return endpointProperties;
}

+ (NSDictionary*)endpointsByShortName
{
    static NSDictionary* endpointsByShortName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary* endByShort = [NSMutableDictionary dictionary];
        
        [self.endpointPropertiesByEndpoint enumerateKeysAndObjectsUsingBlock:^(NSString* endpoint, NSDictionary* properties, BOOL *stop) {
            NSString* shortName = properties[kETAEndpoint_ShortName];
            if (shortName)
                [endByShort setValue:endpoint forKey:shortName];
        }];
        
        endpointsByShortName = [NSDictionary dictionaryWithDictionary:endByShort];
    });
    return endpointsByShortName;
}

+ (NSString*) endpointForShortName:(NSString*)shortName
{
    if (!shortName)
        return nil;
    return self.endpointsByShortName[shortName];
}

+ (NSArray*) allEndpoints
{
    return [self.endpointPropertiesByEndpoint allKeys];
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
    if (!itemID.length)
        return nil;
    NSString* prefix = [self ernPrefixForEndpoint:endpoint];
    return (prefix) ? [NSString stringWithFormat:@"%@%@", prefix, itemID] : nil;
}


#pragma mark - Cache

+ (NSTimeInterval) cacheLifespanForEndpoint:(NSString*)endpoint
{
    NSNumber* lifespan = [self propertiesForEndpoint:endpoint][kETAEndpoint_CacheLifespan];
    if (!lifespan)
        return kETAEndpoint_DefaultCacheLifespan;
    else
        return lifespan.doubleValue;
}

@end
