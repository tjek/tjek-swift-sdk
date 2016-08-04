//
//  ObjCTestClass.m
//  ShopGunSDKExample
//
//  Created by Laurie Hufford on 20/07/2016.
//  Copyright © 2016 ShopGun. All rights reserved.
//

#import "ObjCTestClass.h"

@import ShopGunSDK;


@implementation ObjCTestClass

+ (void) config {
    NSLog(@"clientId:'%@' sessionId:'%@' appId:'%@'", SGNSDKConfig.clientId, SGNSDKConfig.sessionId, SGNSDKConfig.appId);
    
    SGNSDKConfig.appId = @"sdfg";
    [SGNSDKConfig resetClientId];
    
    NSLog(@"clientId:'%@' sessionId:'%@' appId:'%@'", SGNSDKConfig.clientId, SGNSDKConfig.sessionId, SGNSDKConfig.appId);    
}

+ (void) eventsTracker {
    SGNEventsTracker.flushTimeout = 15;
    SGNEventsTracker.flushLimit = 200;
    SGNEventsTracker.trackId = @"THE TRACK ID";
    SGNEventsTracker.baseURL = [NSURL URLWithString:@"events-staging.shopgun.com"];
    
    [SGNEventsTracker.sharedTracker trackEvent:@"sdfg"];
    [SGNEventsTracker.sharedTracker trackEvent:@"qwerty" properties:@{@"foo":@"bar"}];
    
    // static versions
    [SGNEventsTracker trackEvent:@"sdfg"];
    [SGNEventsTracker trackEvent:@"qwerty" properties:@{@"foo":@"bar"}];
}
+ (void) graphRequest {
    SGNGraphConnection* conn = [[SGNGraphConnection alloc] initWithBaseURL:[NSURL URLWithString:@"https://graph-staging.shopgun.com"]
                                                                   timeout:20];
    
    // start req on custom conn
    SGNGraphRequest* req = [[SGNGraphRequest alloc] initWithQuery:@"query" operationName:@"opName" variables:@{@"foo": @1}];
    [conn start:req completion:^(SGNGraphResponse * _Nullable graphResponse, NSHTTPURLResponse * _Nullable urlResponse, NSError * _Nullable error) {
        NSLog(@"%@ %@ %@", graphResponse.dictionaryValue, urlResponse, error);
    }];
    
    // shorthand for starting request on default connection
    [[[SGNGraphRequest alloc] initWithQuery:@"query" operationName:@"opName" variables:@{@"foo": @1}] start:^(SGNGraphResponse * _Nullable graphResponse, NSHTTPURLResponse * _Nullable urlResponse, NSError * _Nullable error) {
        
    }];
    
}

@end
