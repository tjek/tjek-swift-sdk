//
//  ETA_Session.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ModelObject.h"

#import "ETA_User.h"

@interface ETA_Session : ETA_ModelObject

@property (nonatomic, strong) NSString* token;
@property (nonatomic, strong) NSDate*   expires;
@property (nonatomic, strong) ETA_User* user;
@property (nonatomic, strong) NSString* provider;
@property (nonatomic, strong) NSDictionary* permissions;


- (BOOL) willExpireSoon;
- (BOOL) isExpiryTheSameAsSession:(ETA_Session*)session;
- (BOOL) isExpiryNewerThanSession:(ETA_Session*)session;

- (BOOL) allowsPermission:(NSString*)actionPermission;

- (NSString*) userID;

@end
