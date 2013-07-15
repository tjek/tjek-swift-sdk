//
//  ETA_Session.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Mantle.h"

@interface ETA_Session : MTLModel <MTLJSONSerializing>

@property (nonatomic, strong) NSString* token;
@property (nonatomic, strong) NSDate*   expires;
@property (nonatomic, strong) NSDictionary* user;
@property (nonatomic, strong) NSString* provider;
@property (nonatomic, strong) NSDictionary* permissions;

- (BOOL) willExpireSoon;
- (BOOL) isExpiryTheSameAsSession:(ETA_Session*)session;
- (BOOL) isExpiryNewerThanSession:(ETA_Session*)session;
//- (void) setToken:(NSString*)newToken ifExpiresBefore:(NSString*)expiryDateString;

- (BOOL) allowsPermission:(NSString*)actionPermission;

- (NSString*) userID;

+ (NSDateFormatter *)dateFormatter;

+ (instancetype) sessionFromJSONDictionary:(NSDictionary*)JSONDictionary;
- (NSDictionary*) JSONDictionary;
@end
