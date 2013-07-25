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

typedef enum {
    ETA_PageFlip_InitState_NotInitialized,
    ETA_PageFlip_InitState_Initializing,
    ETA_PageFlip_InitState_Initialized,
} ETA_PageFlip_InitState;

NSString* const ETA_PageFlipErrorDomain = @"ETA_PageFlipErrorDomain";
NSInteger const ETA_PageFlipErrorCode_InitFailed = -1983;


// expose the client to the pageFlip
@interface ETA (PageFlipPrivate)
@property (nonatomic, readonly, strong) ETA_APIClient* client;
@end


@interface ETA_PageFlip () <UIWebViewDelegate>

@property (nonatomic, readwrite, strong) UIWebView* webview;

@property (nonatomic, readwrite, strong) ETA* eta;

@property (nonatomic, readwrite, strong) NSString* catalogID;
@property (nonatomic, readwrite, strong) NSString* pendingShowCatalogRequest;

@property (nonatomic, readwrite, assign) ETA_PageFlip_InitState initState;
@property (nonatomic, readonly, assign) BOOL isInitialized;
@property (nonatomic, readwrite, strong) NSString* uuid;
@property (nonatomic, readwrite, strong) NSURL* baseURL;

@property (nonatomic, readwrite, assign) NSUInteger currentPage;
@property (nonatomic, readwrite, assign) NSUInteger pageCount;
@property (nonatomic, readwrite, assign) CGFloat pageProgress;


@end

@implementation ETA_PageFlip

- (id) init
{
    return [self initWithETA:nil];
}
- (id) initWithETA:(ETA*)eta
{
    return [self initWithETA:eta baseURL:nil];
}
- (id) initWithETA:(ETA*)eta baseURL:(NSURL*)baseURL
{
    if ((self = [super initWithFrame:CGRectZero]))
    {
        if ([self commonInitWithETA:eta baseURL:baseURL] == NO)
            self = nil;
    }
    return self;
}
- (id) initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        if ([self commonInitWithETA:nil baseURL:nil] == NO)
            self = nil;
    }
    return self;
}
- (id) initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        if ([self commonInitWithETA:nil baseURL:nil] == NO)
            self = nil;
    }
    return self;
}

- (BOOL) commonInitWithETA:(ETA*)eta baseURL:(NSURL*)baseURL
{
    eta = (eta) ?: ETA.SDK;
    if (!eta.apiKey || !eta.apiSecret)
    {
        return NO;
    }
    else
    {
        self.eta = eta;
        
        self.verbose = NO;
        self.initState = ETA_PageFlip_InitState_NotInitialized;
        
        self.baseURL = (baseURL) ?: [NSURL URLWithString:kETA_PageFlipBaseURLString];
        
        return YES;
    }
}


- (void) dealloc
{
    // send a close request to the server when the pageflip view is destroyed
    [self closeCatalog];
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


#pragma mark - Catalog View Actions

- (void) loadCatalog:(NSString *)catalogID
{
    [self loadCatalog:catalogID parameters:nil];
}
- (void) loadCatalog:(NSString *)catalogID page:(NSUInteger)pageNumber
{
    [self loadCatalog:catalogID parameters:@{ @"page":@(pageNumber) }];
}
- (void) loadCatalog:(NSString *)catalogID parameters:(NSDictionary*)parameters
{
    if (self.catalogID == catalogID || [self.catalogID isEqualToString:catalogID] || self.initState == ETA_PageFlip_InitState_Initializing)
        return;
    
    self.catalogID = catalogID;
    
    // closing the catalog
    if (catalogID == nil)
    {
        [self closeCatalog];
    }
    else
    {
        [self showCatalogView:catalogID parameters:parameters];
    }
}


- (void) showCatalogView:(NSString *)catalogID parameters:(NSDictionary *)parameters
{
    if (!catalogID)
        return;
    
    
    // tell the proxy we are closing the old one (no-op if not initialized)
    [self performJSProxyMethodWithName:@"catalog-view-close" data:nil];
    
    self.currentPage = 0;
    self.pageCount = 0;
    self.pageProgress = 0;
    
    self.initState = ETA_PageFlip_InitState_Initializing;
    
    // create a new webview, destroying the old
    [self.webview removeFromSuperview];
    self.webview = [[UIWebView alloc] initWithFrame:self.bounds];
    self.webview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webview.delegate = self;
    
    [self addSubview:self.webview];
    
    
    // generate the request we want to send to the proxy
    NSMutableDictionary* data = [@{@"catalog": _catalogID,
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
    self.pendingShowCatalogRequest = jsRequest;
    
    
    // everytime we change catalogID, give ourselves a new uuid
    NSString* uuid = [[self class] generateUUID];
    self.uuid = uuid;
    
    // make we have a valid session before loading the new catalog
    [self.eta connect:^(NSError *error) {
        
        NSString* proxyURL = [NSString stringWithFormat:@"%@proxy/%@/", [self.baseURL absoluteString], uuid];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:proxyURL]];
        
        [self.webview loadRequest:request];
    }];

}

- (void) closeCatalog
{
    // tell the server that we are closing the catalog
    [self performJSProxyMethodWithName:@"catalog-view-close" data:nil];
    
    self.currentPage = 0;
    self.pageCount = 0;
    self.pageProgress = 0;
    
    self.catalogID = nil;
    self.pendingShowCatalogRequest = nil;
    
    [self.webview removeFromSuperview];
    self.webview = nil;
    
    self.initState = ETA_PageFlip_InitState_NotInitialized;
}

- (void) toggleCatalogThumbnails
{
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
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:readyEvent:)]))
            [self.delegate etaPageFlip:self readyEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-session-change"])
    {
        // a session changed event - update the SDK
        ETA_Session* session = [ETA_Session objectFromJSONDictionary:specificEventData];
        if (session)
            [self.eta.client setIfNewerSession:session];
        
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:sessionChangeEvent:)]))
            [self.delegate etaPageFlip:self sessionChangeEvent:session];
    }
    else if ([eventName isEqualToString:@"eta-geolocation-change"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:geolocationChangeEvent:)]))
            [self.delegate etaPageFlip:self geolocationChangeEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-pagechange"])
    {
        self.currentPage = [specificEventData[@"page"] integerValue];
        self.pageCount = [specificEventData[@"pageCount"] integerValue];
        
        if (self.pageCount == 1)
            self.pageProgress = 1.0;
        else if (self.pageCount == 0)
            self.pageProgress = 0.0;
        else
        {
            NSUInteger lastVisiblePage = MAX(1,[[specificEventData[@"pages"] lastObject] integerValue]);
            self.pageProgress = (CGFloat)(lastVisiblePage - 1) / (CGFloat)(self.pageCount - 1);
        }
        
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:catalogViewPageChangeEvent:)]))
            [self.delegate etaPageFlip:self catalogViewPageChangeEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-hotspot"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:catalogViewHotspotEvent:)]))
            [self.delegate etaPageFlip:self catalogViewHotspotEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-singletap"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:catalogViewSingleTapEvent:)]))
            [self.delegate etaPageFlip:self catalogViewSingleTapEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-doubletap"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:catalogViewDoubleTapEvent:)]))
            [self.delegate etaPageFlip:self catalogViewDoubleTapEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-dragstart"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaPageFlip:catalogViewDragStartEvent:)]))
            [self.delegate etaPageFlip:self catalogViewDragStartEvent:specificEventData];
    }
    
    if (!handled && [self.delegate respondsToSelector:@selector(etaPageFlip:triggeredEventWithClass:type:dataDictionary:)])
        [self.delegate etaPageFlip:self triggeredEventWithClass:eventClass type:eventType dataDictionary:eventData];
    
}

#pragma mark - Webview Delegate methods

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (webView != self.webview)
        return;
    
    // init the view
    NSMutableDictionary* data = [@{@"apiKey":self.eta.apiKey,
                                   @"apiSecret":self.eta.apiSecret} mutableCopy];
        
    // setup optional location data
    NSDictionary* geoDict = [self geolocationDictionaryWithLocation:self.eta.location distance:self.eta.distance fromSensor:self.eta.isLocationFromSensor];
    if (geoDict)
        data[@"geolocation"] = geoDict;
    
    // setup optional session data
    NSDictionary* sessionDict = [self sessionDictionaryFromSession:self.eta.client.session];
    if (sessionDict)
        data[@"session"] = sessionDict;
    
    
    NSString* response = nil;
    NSString* pendingRequest = self.pendingShowCatalogRequest;
    self.pendingShowCatalogRequest = nil;
    if (data)
    {
        self.initState = ETA_PageFlip_InitState_Initialized;
        
        response = [self performJSProxyMethodWithName:@"initialize" data:data];
        
        if (pendingRequest)
        {
            [self performJSRequest:pendingRequest];
        }
    }
    else
    {
        NSError* error = [NSError errorWithDomain:ETA_PageFlipErrorDomain
                                             code:ETA_PageFlipErrorCode_InitFailed
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Failed to initialize PageFlip",
                                                     NSLocalizedFailureReasonErrorKey: @"PageFlip initialize call was missing required data - maybe ETA object's API key/secret?"
                                                     }];

        [self webView:webView didFailLoadWithError:error];
    }
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (webView != self.webview)
        return;
    
    [self closeCatalog];
    
    if ([self.delegate respondsToSelector:@selector(etaPageFlip:didFailLoadWithError:)])
        [self.delegate etaPageFlip:self didFailLoadWithError:error];
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (webView != self.webview)
        return NO;
    
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
- (BOOL) isInitialized
{
    return self.initState == ETA_PageFlip_InitState_Initialized;
}
        
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
    if (!jsRequest || !self.isInitialized)
        return nil;
    
    NSString* jsResponse = [self.webview stringByEvaluatingJavaScriptFromString:jsRequest];
    
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
    return [(__bridge NSString *)string lowercaseString];
}

@end
