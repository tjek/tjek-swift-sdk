//
//  ETA_PageFlip.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_PageFlip.h"

#import "ETA.h"
#import "ETA_APIClient.h"
#import "ETA_Session.h"
#import "MTLJSONAdapter.h"



NSString* const ETA_PageFlipErrorDomain = @"ETA_PageFlipErrorDomain";
NSInteger const ETA_PageFlipErrorCode_InitFailed = -1983;


// expose the client to the pageFlip
@interface ETA (PageFlipPrivate)
@property (nonatomic, readonly, strong) ETA_APIClient* client;
@end


@interface ETA_PageFlip () <UIWebViewDelegate>

@property (nonatomic, readwrite, strong) ETA* eta;
@property (nonatomic, readwrite, assign) BOOL isInitialized;
@property (nonatomic, readwrite, strong) NSString* uuid;
@property (nonatomic, readwrite, strong) NSURL* baseURL;

@property (nonatomic, readwrite, strong) NSString* pendingShowCatalogRequest;
@end

@implementation ETA_PageFlip

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
    NSAssert(NO, @"You may not set the UIWebView delegate on an ETA_PageFlip");
}

- (void) setEta:(ETA *)eta
{
    if (_eta == eta)
        return;
    
    [_eta removeObserver:self forKeyPath:@"location"];
    [_eta removeObserver:self forKeyPath:@"distance"];
    [_eta removeObserver:self forKeyPath:@"sensor"];
    _eta = eta;
    [_eta addObserver:self forKeyPath:@"location" options:NSKeyValueObservingOptionNew context:NULL];
    [_eta addObserver:self forKeyPath:@"distance" options:NSKeyValueObservingOptionNew context:NULL];
    [_eta addObserver:self forKeyPath:@"sensor" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"location"] || [keyPath isEqualToString:@"distance"] || [keyPath isEqualToString:@"sensor"])
    {
        if (self.isInitialized)
        {
            SEL selector = @selector(changeLocationWithETALocation);
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:selector object:nil];
            [self performSelector:selector withObject:nil afterDelay:0.1];
        }
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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
        self.uuid = [[self class] generateUUID];
        self.baseURL = (baseURL) ?: [NSURL URLWithString:kETA_PageFlipBaseURLString];
        super.delegate = self;
        
        self.eta = eta;
        [self.eta connect:^(NSError *error) {
            
            NSString* proxyURL = [NSString stringWithFormat:@"%@proxy/%@/", [self.baseURL absoluteString], self.uuid];
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:proxyURL]];
            
            [self loadRequest:request];
        }];
    }
}


#pragma mark - Catalog View Actions

- (void) setCatalogID:(NSString *)catalogID
{
    if (_catalogID == catalogID)
        return;
    
    _catalogID = catalogID;
    
    if (_catalogID == nil)
    {
        [self closeCatalogView];
    }
    else
    {
        [self showCatalogView:_catalogID parameters:nil];
    }
    
}
- (void) showCatalogView:(NSString*)catalogID parameters:(NSDictionary*)parameters
{
    if (!catalogID)
        return;
    
    [self willChangeValueForKey:@"catalogID"];
    _catalogID = catalogID;
    [self didChangeValueForKey:@"catalogID"];
    
    NSMutableDictionary* data = [@{@"catalog": catalogID,
                                   @"page": @1,
                                   @"hotspots": @YES,
                                   @"hotspotOverlay": @NO,
                                   @"canClose": @NO,
                                   @"headless": @YES,
                                   @"outOfBounds": @NO,
                                   @"whiteLabel": @YES,
                                   } mutableCopy];
    if (parameters)
        [data setValuesForKeysWithDictionary:parameters];
    
    NSString* jsRequest = [self jsRequestWithProxyMethodName:@"catalog-view" data:data];
    if (self.isInitialized)
        [self performJSRequest:jsRequest];
    else
        self.pendingShowCatalogRequest = jsRequest;
}

- (void) closeCatalogView
{
    [self willChangeValueForKey:@"catalogID"];
    _catalogID = nil;
    [self didChangeValueForKey:@"catalogID"];
    
    self.pendingShowCatalogRequest = nil;
    
    [self performJSProxyMethodWithName:@"catalog-view-close" data:nil];
}
- (void) toggleCatalogViewThumbnails
{
    if (self.verbose)
        NSLog(@"ETA_PageFlip(%@) Toggling Catalog Thumbnails", self.uuid);
    
    [self performJSProxyMethodWithName:@"catalog-view-thumbnails" data:nil];
}


- (void) changeSession:(ETA_Session*)session
{
    if (!session)
        return;
    
    NSDictionary* sessionJSONDict = session.JSONDictionary;
    [self performJSProxyMethodWithName:@"session-change" data:sessionJSONDict];
}

- (void) changeLocation:(CLLocation*)location distance:(NSNumber*)distance fromSensor:(BOOL)fromSensor
{
    NSDictionary* geoDict = [self geolocationDictionaryWithLocation:location distance:distance fromSensor:fromSensor];
    if (!geoDict)
        return;
    
    [self performJSProxyMethodWithName:@"geolocation-change" data:geoDict];
}

- (void) changeLocationWithETALocation
{
    [self changeLocation:self.eta.location distance:self.eta.distance fromSensor:self.eta.isLocationFromSensor];
}


#pragma mark - Event handling

- (void) eventTriggered:(NSString*)eventClass type:(NSString*)eventType data:(NSDictionary*)eventData
{
    // id must be the same as the one we init'd with
    if ([eventData[@"id"] isEqualToString:self.uuid] == NO)
        return;
    
    NSString* eventName = [eventData[@"eventName"] lowercaseString];
    
    // get the data about that event
    NSDictionary* specificEventData = eventData[@"data"];
    
    BOOL handled = NO;
    if ([eventName isEqualToString:@"eta-proxy-ready"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:readyEvent:)]))
            [self.etaDelegate etaPageFlip:self readyEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-session-change"])
    {
        // a session changed event - update the SDK
        ETA_Session* session = [ETA_Session objectFromJSONDictionary:specificEventData];
        if (session)
            [self.eta.client setIfNewerSession:session];
        
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:sessionChangeEvent:)]))
            [self.etaDelegate etaPageFlip:self sessionChangeEvent:session];
    }
    else if ([eventName isEqualToString:@"eta-geolocation-change"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:geolocationChangeEvent:)]))
            [self.etaDelegate etaPageFlip:self geolocationChangeEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-pagechange"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:catalogViewPageChangeEvent:)]))
            [self.etaDelegate etaPageFlip:self catalogViewPageChangeEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-hotspot"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:catalogViewHotspotEvent:)]))
            [self.etaDelegate etaPageFlip:self catalogViewHotspotEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-singletap"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:catalogViewSingleTapEvent:)]))
            [self.etaDelegate etaPageFlip:self catalogViewSingleTapEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-doubletap"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:catalogViewDoubleTapEvent:)]))
            [self.etaDelegate etaPageFlip:self catalogViewDoubleTapEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-dragstart"])
    {
        if ((handled = [self.etaDelegate respondsToSelector:@selector(etaPageFlip:catalogViewDragStartEvent:)]))
            [self.etaDelegate etaPageFlip:self catalogViewDragStartEvent:specificEventData];
    }
    
    if (!handled && [self.etaDelegate respondsToSelector:@selector(etaPageFlip:triggeredEventWithClass:type:dataDictionary:)])
        [self.etaDelegate etaPageFlip:self triggeredEventWithClass:eventClass type:eventType dataDictionary:eventData];
    
}

#pragma mark - Webview Delegate methods

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
    
    NSString* response = nil;
    if (data)
    {
        response = [self performJSProxyMethodWithName:@"initialize" data:data];
        self.isInitialized = YES;
        
        if (self.pendingShowCatalogRequest)
        {
            [self performJSRequest:self.pendingShowCatalogRequest];
            self.pendingShowCatalogRequest = nil;
        }
    }
    else
    {
        self.isInitialized = NO;
        if ([self.etaDelegate respondsToSelector:@selector(etaPageFlip:didFailLoadWithError:)])
        {
            NSError* error = [NSError errorWithDomain:ETA_PageFlipErrorDomain
                                                 code:ETA_PageFlipErrorCode_InitFailed
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Failed to initialize PageFlip",
                                                         NSLocalizedFailureReasonErrorKey: @"PageFlip initialize call was missing required data - maybe ETA object's API key/secret?"
                                                         }];
            [self.etaDelegate etaPageFlip:self didFailLoadWithError:error];
        }
    }
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([self.etaDelegate respondsToSelector:@selector(etaPageFlip:didFailLoadWithError:)])
        [self.etaDelegate etaPageFlip:self didFailLoadWithError:error];
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
            NSLog(@"ETA_PageFlip(%@) Event: %@", self.uuid, eventDataDictionary);
        
        [self eventTriggered:eventClass type:eventType data:eventDataDictionary];

        return NO;
    }
    return YES;
}


#pragma mark - Utility methods

- (NSString*) jsRequestWithProxyMethodName:(NSString*)name data:(NSDictionary*)data
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
    
    return jsRequest;
}
- (NSString*) performJSRequest:(NSString*)jsRequest
{
    if (!jsRequest)
        return nil;
    
    NSString* jsResponse = [self stringByEvaluatingJavaScriptFromString:jsRequest];
    
    if (self.verbose)
        NSLog(@"ETA_PageFlip(%@) Request: %@\nResponse: '%@'", self.uuid, jsRequest, jsResponse);
    
    return jsResponse;
}
- (NSString*) performJSProxyMethodWithName:(NSString*)name data:(NSDictionary*)data
{
    return [self performJSRequest:[self jsRequestWithProxyMethodName:name data:data]];
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
