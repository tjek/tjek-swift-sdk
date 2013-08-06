//
//  ETA_PermissionCategories.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (ETA_Permission)

- (BOOL) allowsPermission:(NSString*)actionPermission;

@end

// assumes dictionary is in the correct form. eg:
// @{   @"group1": @[ @"permission1", @"permssion2" ],
//      @"group2": @[ @"permission1" ] };
@interface NSDictionary (ETA_Permission)

- (BOOL) allowsPermission:(NSString*)actionPermission;

@end