//
//  ETA_APIClient.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "AFHTTPClient.h"

static NSString * const kETA_APIBaseURLString = @"https://api.etilbudsavis.dk/";

@class ETA_Session;

@interface ETA_APIClient : AFHTTPClient

+ (instancetype)clientWithApiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret; // using the production base URL
+ (instancetype)clientWithBaseURL:(NSURL *)url apiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret;

@property (nonatomic, readonly, strong) NSString *apiKey;
@property (nonatomic, readonly, strong) NSString *apiSecret;

@property (nonatomic, strong) ETA_Session* session;

@end
