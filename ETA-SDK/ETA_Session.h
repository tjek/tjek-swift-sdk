//
//  ETA_Session.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Mantle.h"

@class ETA_APIClient;

@interface ETA_Session : MTLModel <MTLJSONSerializing>

@property (nonatomic, strong) NSString* token;
@property (nonatomic, strong) NSDate*   expires;
@property (nonatomic, strong) NSDictionary* user;
@property (nonatomic, strong) NSString* provider;
@property (nonatomic, strong) NSDictionary* permissions;


- (BOOL) willExpireSoon;
- (BOOL) isExpirySameOrNewerThanSession:(ETA_Session*)session;
- (void) setToken:(NSString*)newToken ifExpiresBefore:(NSString*)expiryDateString;
@end
