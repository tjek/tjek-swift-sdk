//
//  ETA_Session.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_Session.h"

#import "NSString+ETA_Permission.h"

static NSTimeInterval const kETA_SoonToExpireTimeInterval = 86400; // 1 day

@implementation ETA_Session

+ (NSDateFormatter *)dateFormatter {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZ";
    return dateFormatter;
}

+ (NSValueTransformer *)expiresJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [self.dateFormatter dateFromString:str];
    } reverseBlock:^(NSDate *date) {
        return [self.dateFormatter stringFromDate:date];
    }];
}


+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{};
}



#pragma mark - Utilities
- (BOOL) willExpireSoon
{
    return (!self.expires || [self.expires timeIntervalSinceNow] <= kETA_SoonToExpireTimeInterval); // will expire in less than a day
}

- (BOOL) isExpirySameOrNewerThanSession:(ETA_Session*)session
{
    if (!session.expires)
        return YES;
    if (!self.expires)
        return NO;
    return ([self.expires compare:session.expires] != NSOrderedAscending);
}

- (void) setToken:(NSString*)newToken ifExpiresBefore:(NSString*)expiryDateString
{
    NSDate* newExpiryDate = [[[self class] expiresJSONTransformer] transformedValue:expiryDateString];
    
    if (!newExpiryDate || !newToken)
        return;

    if (!self.expires || [self.expires compare:newExpiryDate] == NSOrderedAscending)
    {
        self.token = newToken;
        self.expires = newExpiryDate;
    }
}


- (BOOL) allowsPermission:(NSString*)actionPermission
{
    if (!actionPermission)
        return YES;
    if (!self.permissions)
        return NO;
    
    __block BOOL allowed = NO;
    [self.permissions enumerateKeysAndObjectsUsingBlock:^(NSString* permissionGroupName, NSArray* permissionList, BOOL *stop) {
        [permissionList enumerateObjectsUsingBlock:^(NSString* permission, NSUInteger idx, BOOL *stop) {
            if ([permission allowsPermission:actionPermission])
            {
                allowed = YES;
                *stop = YES;
            }
        }];
    }];
    
    return allowed;
}

- (NSString*) userID
{
    return self.user[@"id"];
}

@end
