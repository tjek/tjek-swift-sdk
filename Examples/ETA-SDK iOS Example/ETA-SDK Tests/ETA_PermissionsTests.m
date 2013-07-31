//
//  ETA_PermissionsTests.m
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/31/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//


#import "ETA_PermissionsTests.h"

#import "ETA_PermissionCategories.h"

@implementation ETA_PermissionsTests

- (void) testStringPermissions
{
    NSString* permission = @"api.users.12345.read";
    
    STAssertTrue([permission allowsPermission:@"api.users.12345.read"], @"");
    STAssertTrue([permission allowsPermission:@"api.users.*"], @"");
    STAssertTrue([permission allowsPermission:@"api.users.*.read"], @"");
    STAssertTrue([permission allowsPermission:@"api.users.*.read"], @"");
    
    STAssertTrue([permission allowsPermission:@"*"], @"");
    STAssertTrue([permission allowsPermission:nil], @"");
    STAssertTrue([permission allowsPermission:@""], @"");
    
    STAssertFalse([permission allowsPermission:@"api.users.*.write"], @"");
    STAssertFalse([permission allowsPermission:@"api.users"], @"");
    
    permission = @"api.users.*.read";
    STAssertTrue([permission allowsPermission:@"api.users.12345.read"], @"");
    STAssertTrue([permission allowsPermission:@"api.users.*.read"], @"");
    STAssertTrue([permission allowsPermission:@"api.users.*.read.1234"], @"");
    
    STAssertFalse([permission allowsPermission:@"api.users.12345.write"], @"");
    STAssertFalse([permission allowsPermission:@"api.users.*.write"], @"");
    STAssertFalse([permission allowsPermission:@"fail"], @"");
}

- (void) testDictionaryPermissions
{    
    NSDictionary* permissions = @{ @"guest": @[
                                           @"api.public",
                                           @"api.users.create",
                                           ],
                                   @"user": @[
                                           @"api.public",
                                           ],
                                   @"lh@etilbudsavis.dk": @[
                                           @"api.users.12345.read",
                                           @"api.users.12345.update",
                                           @"api.users.12345.delete",
                                           ],
                                   };
    
    STAssertTrue([permissions allowsPermission:@"api.users.*"], @"");
    STAssertTrue([permissions allowsPermission:@"api.users.*.delete"], @"");
    STAssertTrue([permissions allowsPermission:@"api.users.12345.*"], @"");
    STAssertTrue([permissions allowsPermission:@"api.users.12345.read"], @"");
    STAssertTrue([permissions allowsPermission:@"api.users.create"], @"");
    
    STAssertTrue([permissions allowsPermission:@"*"], @"");
    STAssertTrue([permissions allowsPermission:nil], @"");
    STAssertTrue([permissions allowsPermission:@""], @"");
    
    STAssertFalse([permissions allowsPermission:@"api.users.12345.fail"], @"");
    STAssertFalse([permissions allowsPermission:@"api.users"], @"");
    
    // malformed permissions dict
    permissions = @{};
    STAssertFalse([permissions allowsPermission:@"*"], @"");    
    permissions = @{ @"guest": @"api.public" };
    STAssertFalse([permissions allowsPermission:@"*"], @"");
    permissions = @{ @"guest": @1 };
    STAssertFalse([permissions allowsPermission:@"*"], @"");
    permissions = @{ @"guest": @[ @1 ] };
    STAssertFalse([permissions allowsPermission:@"*"], @"");
    permissions = @{ @"guest": @[ NSNull.null ] };
    STAssertFalse([permissions allowsPermission:@"*"], @"");
    
}

@end
