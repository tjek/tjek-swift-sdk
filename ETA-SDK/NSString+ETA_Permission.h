//
//  NSString+ETA_Permission.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (ETA_Permission)

- (BOOL) allowsPermission:(NSString*)actionPermission;

@end
