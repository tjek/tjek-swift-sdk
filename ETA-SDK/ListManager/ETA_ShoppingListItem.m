//
//  ETA_ShoppingListItem.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ShoppingListItem.h"
#import "ETA_API.h"
#import "NSValueTransformer+ETAPredefinedValueTransformers.h"


NSString* const kETA_ShoppingListItem_MetaCommentKey = @"eta_comment";

@implementation ETA_ShoppingListItem

+ (NSString*) APIEndpoint { return ETA_API.shoppingListItems; }


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey mtl_dictionaryByAddingEntriesFromDictionary:@{ @"name": @"description",
                                                                                           @"offerID": @"offer_id",
                                                                                           @"shoppingListID":   @"shopping_list_id",
                                                                                           @"prevItemID": @"previous_id",
                                                                                        }];
}

+ (NSValueTransformer *)modifiedJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}

+ (NSValueTransformer *)tickJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(id fromJSON) {
        return fromJSON;
    } reverseBlock:^NSString*(NSNumber* fromModel) {
        return (fromModel.boolValue) ? @"true" : @"false";
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

+ (NSValueTransformer *)offerIDJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id fromJSON) {
        if (([fromJSON isKindOfClass:NSString.class] && ((NSString*)fromJSON).length==0) || [fromJSON isEqual:NSNull.null])
            fromJSON = nil;
        return fromJSON;
    } reverseBlock:^id(NSString* fromModel) {
        return (!fromModel || [fromModel isEqual:NSNull.null]) ? @"" : fromModel;
    }];
}


@end
