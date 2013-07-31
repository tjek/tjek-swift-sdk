//
//  ETA_PermissionCategories.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_PermissionCategories.h"

@implementation NSString (ETA_Permission)

- (BOOL) allowsPermission:(NSString*)actionPermission
{
    if (!actionPermission.length)
        return YES;
    
    NSArray* actionTokens = [actionPermission tokenizePermission];
    NSArray* permissionTokens = [self tokenizePermission];
    
    BOOL allowed = NO;
    
    for (NSUInteger i=0; i<permissionTokens.count; i++)
    {
        if (i < actionTokens.count)
        {
            NSString* actionToken = actionTokens[i];
            NSString* permissionToken = permissionTokens[i];
            if ([actionToken isEqualToString:permissionToken])
            {
                allowed = YES;
            }
            else if ([permissionToken isEqualToString:@"*"])
            {
                allowed = YES;
            }
            else if ([actionToken isEqualToString:@"*"])
            {
                allowed = YES;
                // if the last action token is a '*' all extra permissions are allowed
                if (i == actionTokens.count-1)
                    break;
            }
            else
            {
                allowed = NO;
                break;
            }
        }
        else
        {
            allowed = NO;
            break;
        }
    }
    return allowed;
}

- (NSArray*) tokenizePermission
{
    return [[self lowercaseString] componentsSeparatedByString:@"."];
}

@end


@implementation NSDictionary (ETA_Permission)

- (BOOL) allowsPermission:(NSString*)actionPermission
{
    if (!actionPermission.length)
        return YES;
    
    __block BOOL allowed = NO;
    [self enumerateKeysAndObjectsUsingBlock:^(NSString* permissionGroupName, id permissionList, BOOL *stop) {
        if ([permissionList isKindOfClass:[NSArray class]] == NO) {
            *stop = YES;
            return;
        }
        [(NSArray*)permissionList enumerateObjectsUsingBlock:^(id permission, NSUInteger idx, BOOL *stop) {
            if ([permission isKindOfClass:[NSString class]] == NO) {
                *stop = YES;
                return;
            }
            
            if ([(NSString*)permission allowsPermission:actionPermission])
            {
                allowed = YES;
                *stop = YES;
            }
        }];
    }];
    
    return allowed;
}

@end
