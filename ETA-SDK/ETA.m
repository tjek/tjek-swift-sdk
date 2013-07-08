//
//  ETA.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA.h"

#import "AFNetworking.h"

@implementation ETA
+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret
{
    ETA* eta = [[ETA alloc] init];
    
    eta.apiKey = apiKey;
    eta.apiSecret = apiSecret;

    return eta;
}

- (id) init
{
    if ((self = [super init]))
    {
        
    }
    return self;
}

@end
