//
//  ETA_ShoppingListItem.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ShoppingListItem.h"
#import "ETA_APIEndpoints.h"

@implementation ETA_ShoppingListItem

+ (NSString*) APIEndpoint { return ETA_APIEndpoints.shoppingListItems; }


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey mtl_dictionaryByAddingEntriesFromDictionary:@{ @"name": @"description",
                                                                                           @"offerID": @"offer_id",
                                                                                           @"shoppingListID": @"shopping_list_id"
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

+ (NSValueTransformer *)tickJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(id fromJSON) {
        return fromJSON;
    } reverseBlock:^(NSNumber* fromModel) {
        return (fromModel.boolValue) ? @"true" : @"false";
    }];
}

+ (NSValueTransformer *)offerIDJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(id fromJSON) {
        if (([fromJSON isKindOfClass:NSString.class] && ((NSString*)fromJSON).length==0) || [fromJSON isEqual:NSNull.null])
            fromJSON = nil;
        return fromJSON;
    } reverseBlock:^(NSString* fromModel) {
        return (!fromModel || [fromModel isEqual:NSNull.null]) ? @"" : fromModel;
    }];
}


@end
