//
//  ETA_User.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_User.h"
#import "ETA_APIEndpoints.h"

#import "ETA_PermissionCategories.h"

@implementation ETA_User

+ (NSString*) APIEndpoint { return ETA_APIEndpoints.users; }


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    // session's dont have id/ern in the JSON
    return [super.JSONKeyPathsByPropertyKey
            mtl_dictionaryByAddingEntriesFromDictionary:@{ @"birthYear": @"birth_year",
                                                           }];
}


+ (NSValueTransformer *)genderJSONTransformer {
    NSDictionary *genders = @{
                             @"male": @(ETA_UserGender_Male),
                             @"female": @(ETA_UserGender_Female),
                             };
    
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *genderStr) {
        NSNumber* genderNum = (genderStr) ? genders[[genderStr lowercaseString]] : nil;
        return (genderNum) ?: @(ETA_UserGender_Unknown);
    } reverseBlock:^(NSNumber *genderNum) {
        return [genders allKeysForObject:genderNum].lastObject;
    }];
}


#pragma mark - 

- (BOOL) allowsPermission:(NSString*)actionPermission
{
    return [self.permissions allowsPermission:actionPermission];
}
@end