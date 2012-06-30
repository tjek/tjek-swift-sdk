//
//  ETA.m
//  ETA
//
//  Created by Rasmus Hummelmose on 29/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ETA.h"

#define BASE_URL @"https://etilbudsavis.dk"

@interface ETA()

@property (nonatomic) float latitude;
@property (nonatomic) float longitude;
@property (nonatomic) int distance;
@property (nonatomic) BOOL geocoded;
@property (nonatomic) int locationDetermined;
@property (nonatomic) double accuracy;
@property (nonatomic) BOOL hasLocation;
@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, strong) NSURLConnection *connection;

@end

@implementation ETA

// Public properties
@synthesize apiKey = _apiKey;
@synthesize apiSecret = _apiSecret;
@synthesize UUID = _UUID;

// Private properties
@synthesize delegate = _delegate;
@synthesize latitude = _latitude;
@synthesize longitude = _longitude;
@synthesize distance = _distance;
@synthesize geocoded = _geocoded;
@synthesize accuracy = _accuracy;
@synthesize locationDetermined = _locationDetermined;
@synthesize hasLocation = _hasLocation;
@synthesize request = _request;
@synthesize connection = _connection;


#pragma mark - Initializer

+ (ETA *)etaWithAPIKey:(NSString *)apiKey andAPISecret:(NSString *)apiSecret
{
    ETA *eta = [[ETA alloc] init];
    eta.apiKey = apiKey;
    eta.apiSecret = apiSecret;
    eta.UUID = [eta generateUuidString];
    return eta;
}


#pragma mark - Location

- (void)setLocationWithAccuracy:(float)accuracy latitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance
{
    if (accuracy && latitude && longitude && locationDetermined) {
        self.geocoded = NO;
        self.accuracy = accuracy;
        self.latitude = latitude;
        self.longitude = longitude;
        self.locationDetermined = locationDetermined;
        if (distance) self.distance = distance;
        self.hasLocation = YES;
    }
    
    else {
        NSLog(@"Accuracy, latitude, longitude and locationDetermined are mandatory arguments.");
    }
}

- (void)setGeocodedLocationWithLatitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance
{
    if (latitude && longitude && locationDetermined) {
        self.geocoded = YES;
        self.latitude = latitude;
        self.longitude = longitude;
        self.locationDetermined = locationDetermined;
        if (distance) self.distance = distance;
        self.hasLocation = YES;
    }
    
    else {
        NSLog(@"Latitude, longitude and locationDetermined are mandatory arguments.");
    }
}


#pragma mark - Request methods

- (void)performAPIRequestWithPathString:(NSString *)pathString requestType:(ETARequestType)requestType optionsDictionary:(NSDictionary *)optionsDictionary
{
    self.request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", BASE_URL, pathString]]];
    
    NSMutableString *dataString = [[NSMutableString alloc] init];
    for (NSString *key in optionsDictionary.keyEnumerator) {
        if (dataString.length == 0) [dataString appendString:@"&"];
        [dataString appendFormat:@"%@=%@", key, [optionsDictionary valueForKey:key]];
    }
    
    if (requestType == ETARequestTypeGET) {
        [self.request setHTTPMethod:@"GET"];
        self.request.URL = [self.request.URL URLByAppendingPathComponent:dataString];
    };
    
    if (requestType == ETARequestTypePOST) {
        NSData *postData = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        [self.request setHTTPMethod:@"POST"];
        [self.request setValue:[NSString stringWithFormat:@"%d", postData.length] forHTTPHeaderField:@"Content-Length"];
        [self.request setValue:@"application/x-www-form-urlencoded charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [self.request setHTTPBody:postData];
    }
    
    self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
    [self.connection start];
}


#pragma mark - Connection Delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Did fail with error: %@", error);
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    return NO;
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSLog(@"Request for challenge: %@", challenge);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"Response: %@", response);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"Data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{  
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}


#pragma mark - Helper methods

- (NSString *)generateUuidString
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    uuidString = [uuidString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return uuidString;
}

@end
