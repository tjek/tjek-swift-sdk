//
//  ETA_ShoppingList.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ShoppingList.h"
#import "ETA_APIEndpoints.h"

@implementation ETA_ShoppingList

+ (NSString*) APIEndpoint { return ETA_APIEndpoints.shoppingLists; }


#pragma mark - Init

+ (instancetype) shoppingListWithUUID:(NSString*)uuid name:(NSString*)name modifiedDate:(NSDate*)modified access:(ETA_ShoppingList_Access)access
{
    if (!uuid || !name)
        return nil;
    
    if (!modified)
        modified = [NSDate date];
    
    NSDictionary* dict = @{ @"uuid": uuid,
                            @"name": name,
                            @"modified": modified,
                            @"access": @(access),
                            };
	return [self modelWithDictionary:dict error:NULL];
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
    
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return access[str];
    } reverseBlock:^(NSNumber *accessNum) {
        return [access allKeysForObject:accessNum].lastObject;
    }];
}

+ (NSValueTransformer *)modifiedJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [self.dateFormatter dateFromString:str];
    } reverseBlock:^(NSDate *date) {
        return [self.dateFormatter stringFromDate:date];
    }];
}


#pragma mark - Handy methods

- (NSString*)accessString
{
    return [[[self class] accessJSONTransformer] reverseTransformedValue:@(self.access)];
}
@end
