//
//  ETA.h
//  ETA
//
//  Created by Rasmus Hummelmose (Tapp ApS) on 29/06/12.
//  Copyright (c) 2012 ETilbudsavis ApS. All rights reserved.
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

- (void)etaWebViewFailedToLoadWithError:(NSString *)error;
- (void)etaWebViewLoaded:(UIWebView *)webView;
- (void)etaWebView:(UIWebView *)webView triggeredEventWithClass:(NSString *)class type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary;

@end

@interface ETA : NSObject

@property (nonatomic, strong) id<ETADelegate> delegate;
@property (nonatomic) BOOL debug;
@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, strong) NSString *apiSecret;
@property (nonatomic, strong) NSString *UUID;

+ (ETA *)etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret;

- (void)setLocationWithAccuracy:(float)accuracy latitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance;
- (void)setGeocodedLocationWithAddress:(NSString *)address latitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance;
- (void)performAPIRequestWithPathString:(NSString *)pathString requestType:(ETARequestType)requestType optionsDictionary:(NSDictionary *)optionsDictionary;

- (UIWebView *)webViewForETA;
- (void)pageflipWithCatalog:(NSString *)catalog page:(NSUInteger)page;
- (void)pageflipWithDealer:(NSString *)dealer page:(NSUInteger)page;
- (void)pageflipClose;

@end
