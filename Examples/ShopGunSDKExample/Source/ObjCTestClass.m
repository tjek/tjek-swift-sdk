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

+ (void) test {
    SGNSDKConfig.appId = @"sdfg";
    
    
    [SGNEventsTracker.sharedTracker trackEvent:@"sdfg"];
}

@end
