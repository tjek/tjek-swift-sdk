//
//  ETA.m
//  ETA
//
//  Created by Rasmus Hummelmose (Tapp ApS) on 29/06/12.
//  Copyright (c) 2012 ETilbudsavis ApS. All rights reserved.
//

#import "ETA.h"
#import <CommonCrypto/CommonDigest.h>

#define BASE_URL @"https://etilbudsavis.dk"

@interface ETA() <UIWebViewDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic) float latitude;
@property (nonatomic) float longitude;
@property (nonatomic) int distance;
@property (nonatomic) BOOL geocoded;
@property (nonatomic) int locationDetermined;
@property (nonatomic) int accuracy;
@property (strong, nonatomic) NSString *address;
@property (nonatomic) BOOL hasLocation;
@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic) NSHTTPURLResponse *response;
@property (nonatomic, strong) UIWebView *webView;

@end

@implementation ETA

// Public properties
@synthesize apiKey = _apiKey;
@synthesize apiSecret = _apiSecret;
@synthesize UUID = _UUID;
@synthesize debug = _debug;

// Private properties
@synthesize delegate = _delegate;
@synthesize latitude = _latitude;
@synthesize longitude = _longitude;
@synthesize distance = _distance;
@synthesize geocoded = _geocoded;
@synthesize accuracy = _accuracy;
@synthesize address = _address;
@synthesize locationDetermined = _locationDetermined;
@synthesize hasLocation = _hasLocation;
@synthesize request = _request;
@synthesize connection = _connection;
@synthesize response = _response;
@synthesize webView = _webView;


#pragma mark - Initializer

+ (ETA *)etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret
{
    ETA *eta = [[ETA alloc] init];
    eta.apiKey = apiKey;
    eta.apiSecret = apiSecret;
    eta.UUID = [eta generateUuidString];
    return eta;
}

- (UIWebView *)webViewForETA
{
    if (!self.apiKey || !self.apiSecret || !self.UUID) {
        NSLog(@"[ETA] API Key, API Secret and UUID are mandatory properties");
    }
    
    else if (!_webView) {
        _webView = [[UIWebView alloc] init];
        _webView.delegate = self;
        _webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/connect", BASE_URL]]];
        [_webView loadRequest:request];
    }
    return _webView;
}


#pragma mark - Page Flip

- (void)pageflipWithCatalog:(NSString *)catalog page:(NSUInteger)page
{
    [self pageflipWithCatalog:catalog dealer:nil page:page];
}

- (void)pageflipWithDealer:(NSString *)dealer page:(NSUInteger)page
{
    [self pageflipWithCatalog:nil dealer:dealer page:page];
}

- (void)pageflipWithCatalog:(NSString *)catalog dealer:(NSString *)dealer page:(NSUInteger)page
{
    if (!self.webView) {
        NSLog(@"[ETA] A UIWebView has to be loaded before calling page flip");
        return;
    }
    
    NSString *pageflipParameters = [NSString stringWithFormat:
                                    @"eta.pageflip.init({%@:'%@',page:%d});",
                                    (catalog ? @"catalog" : @"dealer"),
                                    (catalog ? catalog : dealer),
                                    (page ? page : 1)];
    
    NSString *JSResponse = [self.webView stringByEvaluatingJavaScriptFromString:pageflipParameters];
    if (self.debug) {
        NSLog(@"[ETA] JSON Page Flip Parameters: %@", pageflipParameters);
        NSLog(@"[ETA] JS Page Flip Init Function Returned: %@", JSResponse);
    }
    
    JSResponse = [self.webView stringByEvaluatingJavaScriptFromString:@"eta.pageflip.open();"];
    if (self.debug) {
        NSLog(@"[ETA] JS Page Flip Open Function Returned: %@", JSResponse);
    }
}

- (void)pageflipClose
{
    if (!self.webView) {
        NSLog(@"[ETA] A UIWebView has to be loaded before calling page flip");
        return;
    }
    
    NSString *JSResponse = [self.webView stringByEvaluatingJavaScriptFromString:@"eta.pageflip.close();"];
    if (self.debug) {
        NSLog(@"[ETA] JS Page Flip Close Function Returned: %@", JSResponse);
    }
}


#pragma mark - UIWebView Delegate

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (self.debug) {
        NSLog(@"[ETA] WebView Failed");
    }
    if ([self.delegate respondsToSelector:@selector(etaWebViewFailedToLoadWithError:)]) {
        [self.delegate etaWebViewFailedToLoadWithError:error.debugDescription];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSString *JSResponse = [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"eta.init({apiKey:'%@',apiSecret:'%@',uuid:'%@'});", self.apiKey, self.apiSecret, self.UUID]];
    if (self.debug) {
        NSLog(@"[ETA] JS Init Function Returned: %@", JSResponse);
    }
    if (self.hasLocation) {
        NSString *JSONLocation = [self buildJSONFormattedLocationParameters];
        JSResponse = [self.webView stringByEvaluatingJavaScriptFromString:JSONLocation];
        if (self.debug) {
            NSLog(@"[ETA] JS Location Function Returned: %@", JSResponse);
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(etaWebViewLoaded:)]) {
        [self.delegate etaWebViewLoaded:self.webView];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.description rangeOfString:BASE_URL].location == NSNotFound) {
        if ([self.delegate respondsToSelector:@selector(etaWebView:triggeredEventWithClass:type:dataDictionary:)]) {
            NSString *event = [request.URL.description stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSArray * eventArray = [event componentsSeparatedByString:@":"];
            NSString *eventClass = [eventArray objectAtIndex:0];;
            NSString *eventType = [eventArray objectAtIndex:1];
            NSString *eventDataJSON = [[eventArray subarrayWithRange:NSMakeRange(2, eventArray.count - 2)] componentsJoinedByString:@":"];
            NSDictionary *eventDataDictionary = [NSJSONSerialization JSONObjectWithData:[eventDataJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
            [self.delegate etaWebView:self.webView triggeredEventWithClass:eventClass type:eventType dataDictionary:eventDataDictionary];
        }
        return NO;
    }
    return YES;
}


#pragma mark - Location

- (void)setLocationWithAccuracy:(float)accuracy latitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance
{
    if (accuracy && latitude && longitude && locationDetermined)
    {
        self.geocoded = NO;
        self.accuracy = accuracy;
        self.latitude = latitude;
        self.longitude = longitude;
        self.locationDetermined = locationDetermined;
        if (distance) self.distance = distance;
        self.hasLocation = YES;
    }
    
    else
    {
        NSLog(@"[ETA] Accuracy, latitude, longitude and locationDetermined are mandatory arguments");
    }
}

- (void)setGeocodedLocationWithAddress:(NSString *)address latitude:(float)latitude longitude:(float)longitude locationDetermined:(int)locationDetermined distance:(int)distance;
{
    if (latitude && longitude && locationDetermined)
    {
        self.geocoded = YES;
        self.latitude = latitude;
        self.longitude = longitude;
        self.locationDetermined = locationDetermined;
        if (address) self.address = address;
        if (distance) self.distance = distance;
        self.hasLocation = YES;
    }
    
    else
    {
        NSLog(@"[ETA] Latitude, longitude and locationDetermined are mandatory arguments");
    }
}


#pragma mark - Request methods

- (void)performAPIRequestWithPathString:(NSString *)pathString requestType:(ETARequestType)requestType optionsDictionary:(NSDictionary *)optionsDictionary
{
    NSMutableString * urlString = [NSMutableString string];
    [urlString appendString:BASE_URL];
    [urlString appendString:pathString];
    
    NSArray *requestArray = [self buildRequestArrayWithOptions:optionsDictionary];
    NSString *dataString = [self buildQueryStringFromArray:requestArray];
    
    if (requestType == ETARequestTypeGET)
    {
        [urlString appendFormat:@"?"];
        [urlString appendString:dataString];
        self.request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        [self.request setHTTPMethod:@"GET"];
    };
    
    if (requestType == ETARequestTypePOST)
    {
        self.request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSData *postData = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        [self.request setHTTPMethod:@"POST"];
        [self.request setValue:[NSString stringWithFormat:@"%d", postData.length] forHTTPHeaderField:@"Content-Length"];
        [self.request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [self.request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [self.request setHTTPBody:postData];
    }
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:YES];
}


#pragma mark - Connection Delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (self.debug)
    {
        NSLog(@"[ETA] NSURLConnection didFailWithError: %@", error);
    }
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (self.debug)
    {
        NSHTTPURLResponse *thisResponse = (NSHTTPURLResponse *)response;
        NSLog(@"[ETA] didReceiveResponse: %@", thisResponse);
    }
    self.response = (NSHTTPURLResponse *)response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (self.debug)
    {
        NSLog(@"[ETA] didReceiveData: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    }
    if (self.response.statusCode == 200 && [self.response.URL.description rangeOfString:@"api"].location != NSNotFound)
    {
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONWritingPrettyPrinted error:nil];
        [self.delegate etaRequestSucceededAndReturnedDictionary:jsonDictionary];
    }
    else
    {
        [self.delegate etaRequestFailedWithError:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    if (self.debug)
    {
        NSLog(@"[ETA] canAuthenticateAgainstProtectionSpace: %@", protectionSpace);
    }
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (self.debug)
    {
        NSLog(@"[ETA] didReceiveAutheticationChallenge: %@", challenge);
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}


#pragma mark - Helper methods

- (NSString *)buildJSONFormattedLocationParameters
{
    NSArray *allParameters = [self buildRequestArrayWithOptions:nil];
    NSArray *locationParameters = [allParameters subarrayWithRange:NSMakeRange(2, allParameters.count - 3)];
    
    NSMutableString *string = [NSMutableString string];
    NSUInteger count = 1;
    for (NSDictionary *parameter in locationParameters) {
        NSString *key = [[parameter allKeys] objectAtIndex:0];
        NSString *value = [parameter objectForKey:key];
        [string appendFormat:@"%@:'%@'", key, value];
        [string appendString:(count == locationParameters.count ? @"" : @",")];
        count++;
    }
    
    NSString *finalString = [NSString stringWithFormat:@"eta.Location.save({%@});", string];
    
    if (self.debug) {
        NSLog(@"[ETA] JSON formatted location string evaluated to: %@", finalString);
    }
    
    return finalString;
}

- (NSString *)buildQueryStringFromArray:(NSArray *)array
{
    NSMutableArray *parts = [NSMutableArray array];
    
    for (NSDictionary *keyValuePair in array)
    {
        NSString *key = [[keyValuePair allKeys] objectAtIndex:0];
        NSStream *value = [keyValuePair valueForKey:key];
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
    }
    
    NSString *queryString = [parts componentsJoinedByString: @"&"];
    
    if (self.debug)
    {
        NSLog(@"[ETA] Query string evaluated to: %@", queryString);
    }
    
    return queryString;
}

- (NSArray *)buildRequestArrayWithOptions:(NSDictionary *)options
{
    NSMutableArray *requestArray = [NSMutableArray array];
    
    // Add all parameters that are contained within the ETA object.
    if (self.apiKey)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:self.apiKey forKey:@"api_key"]];
    }
    if (self.UUID)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:self.UUID forKey:@"api_uuid"]];
    }
    [requestArray addObject:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]] forKey:@"api_timestamp"]];
    if (self.latitude)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%f", self.latitude] forKey:@"api_latitude"]];
    }
    if (self.longitude)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%f", self.longitude] forKey:@"api_longitude"]];
    }
    if (self.distance > 0)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", self.distance] forKey:@"api_distance"]];
    }
    if (self.locationDetermined > 0)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", self.locationDetermined] forKey:@"api_locationDetermined"]];
    }
    if (self.geocoded)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:@"1" forKey:@"api_geocoded"]];
    }
    else
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:@"0" forKey:@"api_geocoded"]];
    }
    if (self.accuracy > 0 && !self.geocoded)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", self.accuracy] forKey:@"api_accuracy"]];
    }
    
    // Add the parameters specified by the user.
    for (NSString *key in options.keyEnumerator)
    {
        [requestArray addObject:[NSDictionary dictionaryWithObject:[options valueForKey:key] forKey:key]];
    }
    
    // Build and add the MD5 checksum.
    NSMutableString *concatenatedValues = [[NSMutableString alloc] init];
    for (NSDictionary *keyValuePair in requestArray)
    {
        [concatenatedValues appendString:[[keyValuePair allValues]objectAtIndex:0]];
    }
    [concatenatedValues appendString:self.apiSecret];
    [requestArray addObject:[NSDictionary dictionaryWithObject:[self md5OfString:concatenatedValues] forKey:@"api_checksum"]];
    
    return requestArray;
}

- (NSString *)generateUuidString
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    uuidString = [uuidString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return uuidString;
}

- (NSString *)md5OfString:(NSString*)string
{
    const char *cStr = [string UTF8String];
    unsigned char result[16];
    CC_MD5( cStr, strlen(cStr), result );
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3], 
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

@end
