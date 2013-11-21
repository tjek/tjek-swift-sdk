//
//  ETA_DBSyncModelObject.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_DBSyncModelObject.h"

@implementation ETA_DBSyncModelObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey mtl_dictionaryByAddingEntriesFromDictionary:@{ @"state": NSNull.null, @"syncUserID": NSNull.null}];
}


@end
