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

//
//+ (void) createSessionUsingClient:(ETA_APIClient*)client withCallback:(void (^)(ETA_Session* session, NSError* error))callback;
//
//- (void) renewUsingClient:(ETA_APIClient*)client withCallback:(void (^)(NSError* error))callback;
//- (void) updateUsingClient:(ETA_APIClient*)client withCallback:(void (^)(NSError* error))callback;
//
//

//+ (instancetype) sessionWithToken:(NSString*)token;

//@property (nonatomic, weak) ETA_APIClient* client; // used to connect update

@property (nonatomic, strong) NSString* token;
@property (nonatomic, strong) NSDate*   expires;
@property (nonatomic, strong) NSDictionary* user;
@property (nonatomic, strong) NSString* provider;
@property (nonatomic, strong) NSDictionary* permissions;

- (BOOL) willExpireSoon;

//- (void) update;    // get the latest state of the session
//- (void) renew;     // try to renew the expiration date of the

@end
