//
//  ETA.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ETA : NSObject

+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret;

- (void) connect:(void (^)(NSError* error))callback;

@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, strong) NSString *apiSecret;

@end
