//
//  ETA_DBSyncModelObject.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_DBSyncModelObject.h"

@implementation ETA_DBSyncModelObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey mtl_dictionaryByAddingEntriesFromDictionary:@{ @"state": NSNull.null }];
}


@end
