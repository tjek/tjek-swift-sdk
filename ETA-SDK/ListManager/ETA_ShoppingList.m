//
//  ETA_ShoppingList.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ShoppingList.h"
#import "ETA_ListShare.h"
#import "ETA_API.h"

NSString* const kETA_ShoppingList_MetaThemeKey = @"eta_theme";

@implementation ETA_ShoppingList

+ (NSString*) APIEndpoint { return ETA_API.shoppingLists; }


#pragma mark - Init

+ (instancetype) shoppingListWithUUID:(NSString *)uuid name:(NSString *)name modifiedDate:(NSDate *)modified access:(ETA_ShoppingList_Access)access
{
    return [self listWithUUID:uuid name:name modifiedDate:modified access:access type:ETA_ShoppingList_Type_ShoppingList];
}
+ (instancetype) wishListWithUUID:(NSString *)uuid name:(NSString *)name modifiedDate:(NSDate *)modified access:(ETA_ShoppingList_Access)access
{
    return [self listWithUUID:uuid name:name modifiedDate:modified access:access type:ETA_ShoppingList_Type_WishList];
}

+ (instancetype) listWithUUID:(NSString*)uuid name:(NSString*)name modifiedDate:(NSDate*)modified access:(ETA_ShoppingList_Access)access type:(ETA_ShoppingList_Type)type
{
    if (!uuid || !name)
        return nil;
    
    if (!modified)
        modified = [NSDate date];
    
    NSDictionary* dict = @{ @"uuid": uuid,
                            @"name": name,
                            @"modified": modified,
                            @"access": @(access),
                            @"type": @(type),
                            };
	return [self modelWithDictionary:dict error:NULL];
}

+ (instancetype) objectFromJSONDictionary:(NSDictionary*)JSONDictionary
{
    ETA_ShoppingList* list = [super objectFromJSONDictionary:JSONDictionary];
    for (ETA_ListShare* share in list.shares)
        share.listUUID = list.uuid;
    
    return list;
}

#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey mtl_dictionaryByAddingEntriesFromDictionary:@{ }];
}

+ (NSValueTransformer *)accessJSONTransformer {
    NSDictionary *access = @{
                             @"private": @(ETA_ShoppingList_Access_Private),
                             @"shared": @(ETA_ShoppingList_Access_Shared),
                             @"public": @(ETA_ShoppingList_Access_Public),
                             };
    
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^NSNumber*(NSString *str) {
        return access[str];
    } reverseBlock:^NSString*(NSNumber *accessNum) {
        return [access allKeysForObject:accessNum].lastObject;
    }];
}

+ (NSValueTransformer *)typeJSONTransformer {
    NSNumber* defaultType = @(ETA_ShoppingList_Type_ShoppingList);
    NSDictionary *types = @{
                             @"shopping_list": @(ETA_ShoppingList_Type_ShoppingList),
                             @"wish_list": @(ETA_ShoppingList_Type_WishList),
                             };
    
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^NSNumber*(NSString *str) {
        NSNumber* type = nil;
        if (str.length)
            type = types[str];
        if (!type)
            type = defaultType;
        return type;
    } reverseBlock:^NSString*(NSNumber *typeNum) {
        return [types allKeysForObject:typeNum].lastObject;
    }];
}


+ (NSValueTransformer *)metaJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(id fromJSON) {
        if ([fromJSON isKindOfClass:NSDictionary.class] == NO)
            fromJSON = nil;
        return fromJSON;
    } reverseBlock:^NSDictionary*(NSDictionary* fromModel) {
        if ([fromModel isKindOfClass:NSDictionary.class] == NO)
            fromModel = nil;
        return fromModel;
    }];
}

+ (NSValueTransformer *)sharesJSONTransformer
{
    return [NSValueTransformer mtl_JSONArrayTransformerWithModelClass:ETA_ListShare.class];
}

+ (NSValueTransformer *)modifiedJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}


#pragma mark - Handy methods

- (NSString*)accessString
{
    return [[[self class] accessJSONTransformer] reverseTransformedValue:@(self.access)];
}



- (ETA_ListShare_Access) accessForUserEmail:(NSString*)userEmail
{
    if (userEmail.length)
    {
        userEmail = userEmail.lowercaseString;
        NSArray* shares = self.shares;
        if (shares.count)
        {
            for (ETA_ListShare* share in shares)
            {
                NSString* shareEmail = share.userEmail;
                if ([shareEmail.lowercaseString isEqualToString:userEmail])
                {
                    return share.access;
                }
            }
        }
    }
    else if (!self.syncUserID.length)
    {
        return ETA_ListShare_Access_Owner;
    }
    return ETA_ListShare_Access_None;
}
- (NSArray*)sharesForUserAccessType:(ETA_ListShare_Access)userAccessType
{
    NSMutableArray* matchingShares = [NSMutableArray array];
    NSArray* shares = self.shares;
    if (shares.count)
    {
        for (ETA_ListShare* share in shares)
        {
            ETA_ListShare_Access access = share.access;
            if (access == userAccessType)
                [matchingShares addObject:share];
        }
    }
    return matchingShares;
}

@end
