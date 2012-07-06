//
//  ETA.h
//  ETA
//
//  Created by Rasmus Hummelmose on 29/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    ETARequestTypeGET,
    ETARequestTypePOST
} ETARequestType;

@protocol ETADelegate <NSObject>

@required
- (void)etaRequestSucceededAndReturnedDictionary:(NSDictionary *)dictionary;
- (void)etaRequestFailedWithError:(NSString *)error;

@end

@interface ETA : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) id<ETADelegate> delegate;
@property (nonatomic) BOOL debug;
@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, strong) NSString *apiSecret;
@property (nonatomic, strong) NSString *UUID;

+ (ETA *)etaWithAPIKey:(NSString *)apiKey andAPISecret:(NSString *)apiSecret;

- (void)setLocationWithAccuracy:(float)accuracy latitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance;
- (void)setGeocodedLocationWithLatitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance;
- (void)performAPIRequestWithPathString:(NSString *)pathString requestType:(ETARequestType)requestType optionsDictionary:(NSDictionary *)optionsDictionary;

@end
