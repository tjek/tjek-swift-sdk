//
//  ETA_ListShare.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ListShare.h"
#import "ETA_API.h"

@implementation ETA_ListShare

+ (NSString*) APIEndpoint { return nil; }


#pragma mark - Init


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey mtl_dictionaryByAddingEntriesFromDictionary:@{ @"ern":NSNull.null,
                                                                                           @"uuid":NSNull.null,
                                                                                           @"userEmail":@"user.email",
                                                                                           @"userName":@"user.name",
                                                                                           }];
}

+ (NSValueTransformer *)accessJSONTransformer {
    
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^NSNumber*(NSString *str) {
        return [self shareAccessCodesByString][str];
    } reverseBlock:^NSString*(NSNumber *accessNum) {
        return [[self shareAccessCodesByString] allKeysForObject:accessNum].lastObject;
    }];
}

+ (NSDictionary*) shareAccessCodesByString
{
    return @{ @"owner": @(ETA_ListShare_Access_Owner),
              @"r": @(ETA_ListShare_Access_ReadOnly),
              @"rw": @(ETA_ListShare_Access_ReadWrite),
              };
}

+ (ETA_ListShare_Access) accessForString:(NSString*)shareAccessString
{
    return [[self shareAccessCodesByString][shareAccessString] integerValue];
}
+ (NSString*) stringForAccess:(ETA_ListShare_Access)shareAccess
{
    return [[self shareAccessCodesByString] allKeysForObject:@(shareAccess)].lastObject;
}
@end
