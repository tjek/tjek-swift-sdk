//
//  ETA_Session.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_Session.h"
#import "NSValueTransformer+ETAPredefinedValueTransformers.h"
#import "ETA_API.h"
#import "ETA_PermissionCategories.h"

static NSTimeInterval const kETA_SoonToExpireTimeInterval = 86400; // 1 day

@implementation ETA_Session

+ (NSString*) APIEndpoint { return ETA_API.sessions; }


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    // session's dont have id/ern in the JSON    
    return [super.JSONKeyPathsByPropertyKey
            mtl_dictionaryByAddingEntriesFromDictionary:@{ @"uuid": NSNull.null,
                                                           @"ern": NSNull.null
                                                           }];
}

+ (NSValueTransformer *)expiresJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}

+ (NSValueTransformer *)userJSONTransformer {
    return [NSValueTransformer mtl_JSONDictionaryTransformerWithModelClass:ETA_User.class];
}


#pragma mark - Utilities
- (BOOL) willExpireSoon
{
    return (!self.expires || [self.expires timeIntervalSinceNow] <= kETA_SoonToExpireTimeInterval); // will expire in less than a day
}

- (BOOL) isExpiryTheSameAsSession:(ETA_Session*)session
{
    return (self.expires == session.expires) || ([self.expires compare:session.expires] == NSOrderedSame);
}
- (BOOL) isExpiryNewerThanSession:(ETA_Session*)session
{
    if (!session.expires)
        return YES;
    if (!self.expires)
        return NO;
    return ([self.expires compare:session.expires] == NSOrderedDescending);
}


- (BOOL) allowsPermission:(NSString*)actionPermission
{
    return [self.permissions allowsPermission:actionPermission];
}

- (NSString*) userID
{
    return self.user.uuid;
}

//
//- (NSString*) description
//{
//    NSString* sessionJSON = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:self.JSONDictionary options:NSJSONWritingPrettyPrinted error:nil]
//                                        encoding: NSUTF8StringEncoding];
//    return [NSString stringWithFormat:@"<ETA_Session: %@>", sessionJSON];
//}

@end
