//
//  ETA_WebView.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_WebView.h"

#import "ETA.h"
#import "ETA_APIClient.h"
#import "ETA_Session.h"
#import "MTLJSONAdapter.h"

// expose the client to the webview
@interface ETA (WebViewPrivate)
@property (nonatomic, readonly, strong) ETA_APIClient* client;
@end


@interface ETA_WebView () <UIWebViewDelegate>

@property (nonatomic, readwrite, strong) ETA* eta;
@property (nonatomic, readwrite, assign) BOOL isInitialized;
@property (nonatomic, readwrite, strong) NSString* uuid;
@property (nonatomic, readwrite, strong) NSURL* baseURL;

@end

@implementation ETA_WebView

- (id) init
{
    if ((self = [super init]))
    {
        self.verbose = NO;
        self.isInitialized = NO;
    }
    return self;
}

- (void) dealloc
{
    self.eta = nil;
}

// wrap the delegate in an eta-delegate method
- (void) setDelegate:(id<UIWebViewDelegate>)delegate
{
    NSAssert(NO, @"You may not set the UIWebView delegate on an ETA_WebView");
}


#pragma mark - Starting

- (void) startLoadWithETA:(ETA *)eta
{
    [self startLoadWithETA:eta baseURL:nil];
}
- (void) startLoadWithETA:(ETA *)eta baseURL:(NSURL *)baseURL
{
    if (!eta.apiKey || !eta.apiSecret)
        return;
    
    if (!self.uuid)
    {
        self.eta = eta;
        // TODO: Maybe connect to a session?
        
        super.delegate = self;
        
        self.uuid = [[self class] generateUUID];
        self.baseURL = (baseURL) ?: [NSURL URLWithString:kETA_WebViewBaseURLString];
        
        NSString* proxyURL = [NSString stringWithFormat:@"%@proxy/%@/", [self.baseURL absoluteString], self.uuid];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:proxyURL]];
        
        [self loadRequest:request];
    }
}

- (void) setEta:(ETA *)eta
{
    if (_eta == eta)
        return;
    
    [_eta removeObserver:self forKeyPath:@"client.session"];
    _eta = eta;
    [_eta addObserver:self forKeyPath:@"client.session" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"client.session"])
    {
        if (self.isInitialized)
        {
            ETA_Session* new = change[NSKeyValueChangeNewKey];
            if (new)
            {
                [self changeSession:new];
            }
        }
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Catalog View Actions

- (void) showCatalogView:(NSString*)catalogID parameters:(NSDictionary*)parameters
{
    if (!catalogID)
        return;
    
    if (!self.uuid)
        return;
    //TODO: better defaults?
    NSMutableDictionary* data = [@{@"catalog": catalogID,
                                   @"page": @1,
                                   @"hotspots": @NO,
                                   @"hotspotOverlay": @YES,
                                   @"canClose": @NO,
                                   @"headless": @YES,
                                   @"outOfBounds": @NO,
                                   @"whiteLabel": @YES,
                                   } mutableCopy];
    if (parameters)
        [data setValuesForKeysWithDictionary:parameters];
    
    [self performJSProxyMethodWithName:@"catalog-view" data:data];
}
- (void) closeCatalogView
{
    [self performJSProxyMethodWithName:@"catalog-view-close" data:nil];
}
- (void) toggleCatalogViewThumbnails
{
    [self performJSProxyMethodWithName:@"catalog-view-thumbnails" data:nil];
}
- (void) changeSession:(ETA_Session*)session
{
    if (!session)
        return;
    
    DLog(@"WebView change session '%@' %@", session.token, session.expires);
    
    NSDictionary* sessionJSONDict = session.JSONDictionary;
    [self performJSProxyMethodWithName:@"session-change" data:sessionJSONDict];

}
- (void) changeLocation:(CLLocation*)location distance:(NSNumber*)distance fromSensor:(BOOL)fromSensor
{
    NSDictionary* geoDict = [self geolocationDictionaryWithLocation:location distance:distance fromSensor:fromSensor];
    if (geoDict)
        [self performJSProxyMethodWithName:@"geolocation-change" data:geoDict];
}

#pragma mark - Event handling

- (void) eventTriggered:(NSString*)eventClass type:(NSString*)eventType data:(NSDictionary*)eventData
{
    // id must be the same as the one we init'd with
    if ([eventData[@"id"] isEqualToString:self.uuid] == NO)
        return;
    
    NSString* eventName = [eventData[@"eventName"] lowercaseString];
    
    BOOL handled = NO;
    if ([eventName isEqualToString:@"eta-proxy-ready"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:proxyReadyEvent:)]))
            [self.etaDelegate etaWebView:self proxyReadyEvent:eventData];
    }
    else if ([eventName isEqualToString:@"eta-session-change"])
    {
        // a session changed event - update the SDK
        ETA_Session* session = [ETA_Session objectFromJSONDictionary:eventData[@"data"]];
        if (session)
            [self.eta.client setIfNewerSession:session];
        
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:sessionChangeEvent:)]))
            [self.etaDelegate etaWebView:self sessionChangeEvent:eventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-pagechange"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:catalogViewPageChangeEvent:)]))
            [self.etaDelegate etaWebView:self catalogViewPageChangeEvent:eventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-outofbounds"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:catalogViewOutOfBoundsEvent:)]))
            [self.etaDelegate etaWebView:self catalogViewOutOfBoundsEvent:eventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-hotspot"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:catalogViewHotspotEvent:)]))
            [self.etaDelegate etaWebView:self catalogViewHotspotEvent:eventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-singletap"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:catalogViewSingleTapEvent:)]))
            [self.etaDelegate etaWebView:self catalogViewSingleTapEvent:eventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-doubletap"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:catalogViewDoubleTapEvent:)]))
            [self.etaDelegate etaWebView:self catalogViewDoubleTapEvent:eventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-dragstart"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaWebView:catalogViewDragStartEvent:)]))
            [self.etaDelegate etaWebView:self catalogViewDragStartEvent:eventData];
    }
    
    if (!handled && [self.etaDelegate respondsToSelector:@selector(etaWebView:triggeredEventWithClass:type:dataDictionary:)])
        [self.etaDelegate etaWebView:self triggeredEventWithClass:eventClass type:eventType dataDictionary:eventData];
    
}

#pragma mark - Webview Delegate methods

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if ([self.etaDelegate respondsToSelector:@selector(etaWebViewDidStartLoad:)])
        [self.etaDelegate etaWebViewDidStartLoad:self];

}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    
    NSMutableDictionary* data = nil;
    if (self.eta)
    {
        data = [@{@"apiKey":self.eta.apiKey,
                  @"apiSecret":self.eta.apiSecret} mutableCopy];
        
        // setup optional location data
        NSDictionary* geoDict = [self geolocationDictionaryWithLocation:self.eta.location distance:self.eta.distance fromSensor:self.eta.isLocationFromSensor];
        if (geoDict)
            data[@"geolocation"] = geoDict;
        
        // setup optional session data
        NSDictionary* sessionDict = [self sessionDictionaryFromSession:self.eta.client.session];
        if (sessionDict)
            data[@"session"] = sessionDict;
    }
    
    DLog(@"Init Webview with session: '%@' %@", self.eta.client.session.token, self.eta.client.session.expires);
    
    NSString* response = nil;
    if (data)
        response = [self performJSProxyMethodWithName:@"initialize" data:data];
    
    self.isInitialized = YES;
    
    if ([self.etaDelegate respondsToSelector:@selector(etaWebViewDidFinishLoad:)])
        [self.etaDelegate etaWebViewDidFinishLoad:self];
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([self.etaDelegate respondsToSelector:@selector(etaWebView:didFailLoadWithError:)])
        [self.etaDelegate etaWebView:self didFailLoadWithError:error];
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // the webview tried to load a url that isnt within the baseURL of the SDK
    if ([request.URL.description rangeOfString:[self.baseURL absoluteString]].location == NSNotFound)
    {
        // forward the message to the delegate
        NSString *event = [request.URL.description stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSArray * eventArray = [event componentsSeparatedByString:@":"];
        NSString *eventClass = [eventArray objectAtIndex:0];;
        NSString *eventType = [eventArray objectAtIndex:1];
        NSString *eventDataJSON = [[eventArray subarrayWithRange:NSMakeRange(2, eventArray.count - 2)] componentsJoinedByString:@":"];
        NSDictionary *eventDataDictionary = [NSJSONSerialization JSONObjectWithData:[eventDataJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
        
        if (self.verbose)
            NSLog(@"ETA_WebView(%@) Event: %@", self.uuid, eventDataDictionary);
        
        [self eventTriggered:eventClass type:eventType data:eventDataDictionary];

        return NO;
    }
    return YES;
}


#pragma mark - Utility methods

- (NSString*) performJSProxyMethodWithName:(NSString*)name data:(NSDictionary*)data
{
    NSString* jsRequest = nil;
    if (name)
    {
        if (data)
        {
            NSString* dataStr = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:data options:0 error:nil]
                                                      encoding: NSUTF8StringEncoding];
            
            if (dataStr)
                jsRequest = [NSString stringWithFormat:@"window.etaProxy.push(['%@', '%@']);", name, dataStr];
        }
        else
            jsRequest = [NSString stringWithFormat:@"window.etaProxy.push(['%@']);", name];
    }
    
    if (!jsRequest)
        return nil;
    
    NSString* jsResponse = [self stringByEvaluatingJavaScriptFromString:jsRequest];
    
    if (self.verbose)
        NSLog(@"ETA_WebView(%@) Request: %@\nResponse: '%@'", self.uuid, jsRequest, jsResponse);
    return jsResponse;
}


- (NSDictionary*)geolocationDictionaryWithLocation:(CLLocation*)location distance:(NSNumber*)distance fromSensor:(BOOL)fromSensor
{
    NSMutableDictionary* geoDict = nil;
    // setup optional location data
    if (location)
    {
        geoDict = [@{} mutableCopy];
        geoDict[@"longitude"] = @(location.coordinate.longitude);
        geoDict[@"latitude"] = @(location.coordinate.latitude);
        geoDict[@"sensor"] = @(fromSensor);
        if (distance)
            geoDict[@"radius"] = distance;
    }
    return geoDict;
}

- (NSDictionary*)sessionDictionaryFromSession:(ETA_Session*)session
{
    NSDictionary* sessionDict = nil;
    if (session)
    {
        sessionDict = session.JSONDictionary;
    }
    return sessionDict;
}



+ (NSString*) generateUUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge NSString *)string;
}

@end
