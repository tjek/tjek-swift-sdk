//
//  ETA_ModelItem.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ModelItem.h"

@implementation ETA_ModelItem


+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"itemID": @"id" };
}


+ (NSString*) ernForItemID:(NSString*)itemID
{
    return nil;
}

@end
