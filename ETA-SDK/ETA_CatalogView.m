//
//  ETA_CatalogView.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_CatalogView.h"

#import "ETA.h"
#import "ETA_APIClient.h"
#import "ETA_Session.h"
#import "MTLJSONAdapter.h"

#import "ETA_Log.h"

typedef enum {
    ETA_CatalogView_InitState_NotInitialized,
    ETA_CatalogView_InitState_Initializing,
    ETA_CatalogView_InitState_Initialized,
} ETA_CatalogView_InitState;

NSString* const ETA_CatalogViewErrorDomain = @"ETA_CatalogViewErrorDomain";
NSInteger const ETA_CatalogViewErrorCode_InitFailed = -1983;


// expose the client to the catalogView
@interface ETA (CatalogViewPrivate)
@property (nonatomic, readonly, strong) ETA_APIClient* client;
@end


@interface ETA_CatalogView () <UIWebViewDelegate>

@property (nonatomic, readwrite, strong) UIWebView* webview;

@property (nonatomic, readwrite, strong) ETA* eta;

@property (nonatomic, readwrite, strong) NSString* catalogID;
@property (nonatomic, readwrite, strong) NSString* pendingShowCatalogRequest;

@property (nonatomic, readwrite, assign) ETA_CatalogView_InitState initState;
@property (nonatomic, readonly, assign) BOOL isInitialized;
@property (nonatomic, readwrite, strong) NSString* uuid;
@property (nonatomic, readwrite, strong) NSURL* baseURL;

@property (nonatomic, readwrite, assign) NSUInteger currentPage;
@property (nonatomic, readwrite, assign) NSUInteger pageCount;
@property (nonatomic, readwrite, assign) CGFloat pageProgress;

@property (nonatomic, strong) dispatch_queue_t requestQ;

@end

@implementation ETA_CatalogView

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
        
        self.initState = ETA_CatalogView_InitState_NotInitialized;
        
        self.baseURL = (baseURL) ?: [NSURL URLWithString:kETA_CatalogViewBaseURLString];
        
        self.requestQ = dispatch_queue_create("com.eTilbudsavis.CatalogViewRequestQ", NULL);
        
        return YES;
    }
}


- (void) dealloc
{
    self.delegate = nil;
    self.eta = nil;
    
    // send a close request to the server when the catalog view is destroyed
    [self closeCatalog];
}

- (void) setEta:(ETA *)eta
{
    if (_eta == eta)
        return;
    
    [_eta removeObserver:self forKeyPath:@"geolocation"];
    [_eta removeObserver:self forKeyPath:@"radius"];
    [_eta removeObserver:self forKeyPath:@"isLocationFromSensor"];
    [_eta removeObserver:self forKeyPath:@"client.session"];
    _eta = eta;
    [_eta addObserver:self forKeyPath:@"geolocation" options:NSKeyValueObservingOptionNew context:NULL];
    [_eta addObserver:self forKeyPath:@"radius" options:NSKeyValueObservingOptionNew context:NULL];
    [_eta addObserver:self forKeyPath:@"isLocationFromSensor" options:NSKeyValueObservingOptionNew context:NULL];
    [_eta addObserver:self forKeyPath:@"client.session" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"geolocation"] || [keyPath isEqualToString:@"radius"] || [keyPath isEqualToString:@"isLocationFromSensor"])
    {
        if (self.isInitialized)
        {
            SEL selector = @selector(changeLocationWithETAGeolocation);
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:selector object:nil];
            [self performSelector:selector withObject:nil afterDelay:0.1];
        }
    }
    else if ([keyPath isEqualToString:@"client.session"])
    {
        if (_eta.client.session != nil)
        {
            [self changeSession:_eta.client.session];
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
    if (self.catalogID == catalogID || [self.catalogID isEqualToString:catalogID] || self.initState == ETA_CatalogView_InitState_Initializing)
        return;
    
    self.catalogID = catalogID;
    _pauseCatalog = NO;
    
    
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
    
    self.initState = ETA_CatalogView_InitState_Initializing;
    
    // create a new webview, destroying the old
    [self.webview removeFromSuperview];
    self.webview = [[UIWebView alloc] initWithFrame:self.bounds];
    self.webview.scrollView.scrollEnabled = NO;
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
    
    self.initState = ETA_CatalogView_InitState_NotInitialized;
}

- (void) setPauseCatalog:(BOOL)pauseCatalog
{
    if (_pauseCatalog == pauseCatalog)
        return;
    
    _pauseCatalog = pauseCatalog;
    
    if (self.pauseCatalog)
        [self performJSProxyMethodWithName:@"pause" data:nil];
    else
        [self performJSProxyMethodWithName:@"resume" data:nil];
}

- (void) toggleCatalogThumbnails
{
    [self performJSProxyMethodWithName:@"catalog-view-thumbnails" data:nil];
}
- (void) gotoPage:(NSUInteger)page animated:(BOOL)animated
{
    [self performJSProxyMethodWithName:@"catalog-view-go-to-page" data:@{@"page": @(page),
                                                                         @"animated":animated?@"true":@"false"}];

}

- (void) changeSession:(ETA_Session*)session
{
    if (!session)
        return;
    
    NSDictionary* sessionJSONDict = session.JSONDictionary;
    [self performJSProxyMethodWithName:@"session-change" data:sessionJSONDict];
}

- (void) changeLocation:(CLLocation*)location radius:(NSNumber*)radius fromSensor:(BOOL)fromSensor
{
    NSDictionary* geoDict = [self geolocationDictionaryWithLocation:location radius:radius fromSensor:fromSensor];
    if (!geoDict)
        return;
    
    [self performJSProxyMethodWithName:@"geolocation-change" data:geoDict];
}

- (void) changeLocationWithETAGeolocation
{
    [self changeLocation:self.eta.geolocation radius:self.eta.radius fromSensor:self.eta.isLocationFromSensor];
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
        [self proxyReadyEvent:specificEventData];
        handled = YES;
    }
    else if ([eventName isEqualToString:@"eta-session-change"])
    {
        // a session changed event - update the SDK
        ETA_Session* session = [ETA_Session objectFromJSONDictionary:specificEventData];
        if (session)
            [self.eta.client setIfNewerSession:session];
        
        if ((handled = [self.delegate respondsToSelector:@selector(etaCatalogView:sessionChangeEvent:)]))
            [self.delegate etaCatalogView:self sessionChangeEvent:session];
    }
    else if ([eventName isEqualToString:@"eta-geolocation-change"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaCatalogView:geolocationChangeEvent:)]))
            [self.delegate etaCatalogView:self geolocationChangeEvent:specificEventData];
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
        
        if ((handled = [self.delegate respondsToSelector:@selector(etaCatalogView:catalogViewPageChangeEvent:)]))
            [self.delegate etaCatalogView:self catalogViewPageChangeEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-hotspot"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaCatalogView:catalogViewHotspotEvent:)]))
            [self.delegate etaCatalogView:self catalogViewHotspotEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-singletap"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaCatalogView:catalogViewSingleTapEvent:)]))
            [self.delegate etaCatalogView:self catalogViewSingleTapEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-doubletap"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaCatalogView:catalogViewDoubleTapEvent:)]))
            [self.delegate etaCatalogView:self catalogViewDoubleTapEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-catalog-view-dragstart"])
    {
        if ((handled = [self.delegate respondsToSelector:@selector(etaCatalogView:catalogViewDragStartEvent:)]))
            [self.delegate etaCatalogView:self catalogViewDragStartEvent:specificEventData];
    }
    else if ([eventName isEqualToString:@"eta-api-request"])
    {
        [self proxyAPIRequestEvent:specificEventData];
        handled = YES;
    }
    
    if (!handled)
    {
        ETASDKLogInfo(@"ETA_CatalogView(%@) Unhandled event: %@", self.uuid, eventName);
        
        if ([self.delegate respondsToSelector:@selector(etaCatalogView:triggeredEventWithClass:type:dataDictionary:)])
            [self.delegate etaCatalogView:self triggeredEventWithClass:eventClass type:eventType dataDictionary:eventData];
    }
    
}

- (void) proxyReadyEvent:(NSDictionary*)eventData
{
    // init the view
    NSMutableDictionary* data = [@{@"apiKey":self.eta.apiKey,
                                   @"apiSecret":self.eta.apiSecret} mutableCopy];
    
    // setup optional location data
    NSDictionary* geoDict = [self geolocationDictionaryWithLocation:self.eta.geolocation radius:self.eta.radius fromSensor:self.eta.isLocationFromSensor];
    if (geoDict)
        data[@"geolocation"] = geoDict;
    
    // setup optional session data
    NSDictionary* sessionDict = [self sessionDictionaryFromSession:self.eta.client.session];
    if (sessionDict)
        data[@"session"] = sessionDict;
    
    
    NSString* pendingRequest = self.pendingShowCatalogRequest;
    self.pendingShowCatalogRequest = nil;
    if (data)
    {
        self.initState = ETA_CatalogView_InitState_Initialized;
        [self performJSProxyMethodWithName:@"configure" data:@{ @"overrideAPI": @(YES) }];
        
        [self performJSProxyMethodWithName:@"initialize" data:data];
        
        if (pendingRequest)
        {
            //TODO: Maybe handle responses, if we know how
            [self performJSRequest:pendingRequest];
        }
        
        if ([self.delegate respondsToSelector:@selector(etaCatalogView:readyEvent:)])
            [self.delegate etaCatalogView:self readyEvent:eventData];
    }
}

- (void)proxyAPIRequestEvent:(NSDictionary*)eventData
{
    NSString* requestID = eventData[@"id"];
    NSDictionary* data = eventData[@"data"];
    
    NSString* urlString = data[@"url"];
    NSDictionary* headersDict = data[@"headers"];
    
    NSString* typeString = data[@"type"];
    ETARequestType type = -1;
    if ([typeString caseInsensitiveCompare:@"put"] == NSOrderedSame)
        type = ETARequestTypePUT;
    else if ([typeString caseInsensitiveCompare:@"post"] == NSOrderedSame)
        type = ETARequestTypePOST;
    else if ([typeString caseInsensitiveCompare:@"get"] == NSOrderedSame)
        type = ETARequestTypeGET;
    else if ([typeString caseInsensitiveCompare:@"delete"] == NSOrderedSame)
        type = ETARequestTypeDELETE;
    
    if (!requestID || (NSInteger)type == -1 || !urlString)
        return;
    
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    if (data[@"data"])
        [params addEntriesFromDictionary:data[@"data"]];
    
    
    
    NSString* token = headersDict[@"X-Token"];
    NSString* signature = headersDict[@"X-Signature"];
    
    if (token && signature)
    {
        [self.eta.client.requestSerializer setValue:token forHTTPHeaderField:@"X-Token"];
        [self.eta.client.requestSerializer setValue:signature forHTTPHeaderField:@"X-Signature"];
    }
    
//    if (headersDict)
//        params[@"sessionHeaders"] = headersDict;
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    [self.eta api:urlString
             type:type
       parameters:params
         useCache:YES
       completion:^(id response, NSError * err, BOOL fromCache) {
           NSMutableDictionary* res = [@{ @"id": requestID } mutableCopy];
           
           if (response)
               res[@"success"] = response;
           NSDictionary* errJSON = err.userInfo[ETA_APIError_ErrorObjectKey];
           if (errJSON)
               res[@"error"] = errJSON;
           
           if (ETASDK_IsLogLevel(ETASDK_LogLevel_Debug))
               ETASDKLogDebug(@"[CatalogView] Send proxy request(%@) '%@' %@ took %fsec", typeString, urlString, params, [NSDate timeIntervalSinceReferenceDate] - start);
           
           [self performJSProxyMethodWithName:@"api-request-complete" data:res async:YES];
       }];
    
    if ([self.delegate respondsToSelector:@selector(etaCatalogView:apiRequest:)])
        [self.delegate etaCatalogView:self apiRequest:eventData];
}

#pragma mark - Webview Delegate methods

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
//    if (webView != self.webview)
//        return;
//    
//    // init the view
//    NSMutableDictionary* data = [@{@"apiKey":self.eta.apiKey,
//                                   @"apiSecret":self.eta.apiSecret} mutableCopy];
//        
//    // setup optional location data
//    NSDictionary* geoDict = [self geolocationDictionaryWithLocation:self.eta.geolocation radius:self.eta.radius fromSensor:self.eta.isLocationFromSensor];
//    if (geoDict)
//        data[@"geolocation"] = geoDict;
//    
//    // setup optional session data
//    NSDictionary* sessionDict = [self sessionDictionaryFromSession:self.eta.client.session];
//    if (sessionDict)
//        data[@"session"] = sessionDict;
//    
//    
//    NSString* pendingRequest = self.pendingShowCatalogRequest;
//    self.pendingShowCatalogRequest = nil;
//    if (data)
//    {
//        self.initState = ETA_CatalogView_InitState_Initialized;
//        [self performJSProxyMethodWithName:@"configure" data:@{ @"overrideAPI": @(YES) }];
//        
//        [self performJSProxyMethodWithName:@"initialize" data:data];
//        
//        if (pendingRequest)
//        {
//            //TODO: Maybe handle responses, if we know how
//            [self performJSRequest:pendingRequest];
//        }
//    }
//    else
//    {
//        NSError* error = [NSError errorWithDomain:ETA_CatalogViewErrorDomain
//                                             code:ETA_CatalogViewErrorCode_InitFailed
//                                         userInfo:@{ NSLocalizedDescriptionKey: @"Failed to initialize CatalogView",
//                                                     NSLocalizedFailureReasonErrorKey: @"CatalogView initialize call was missing required data - maybe ETA object's API key/secret?"
//                                                     }];
//
//        [self webView:webView didFailLoadWithError:error];
//    }
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (webView != self.webview)
        return;
    
    [self closeCatalog];
    
    if ([self.delegate respondsToSelector:@selector(etaCatalogView:didFailLoadWithError:)])
        [self.delegate etaCatalogView:self didFailLoadWithError:error];
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (webView != self.webview)
        return NO;
    
    // the webview tried to load a url that isnt within the baseURL of the SDK
    if ([request.URL.absoluteString rangeOfString:[self.baseURL absoluteString]].location == NSNotFound)
    {
        // forward the message to the delegate
        NSString *event = [request.URL.description stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSArray * eventArray = [event componentsSeparatedByString:@":"];
        NSString *eventClass = [eventArray objectAtIndex:0];;
        NSString *eventType = [eventArray objectAtIndex:1];
        NSString *eventDataJSON = [[eventArray subarrayWithRange:NSMakeRange(2, eventArray.count - 2)] componentsJoinedByString:@":"];
        NSDictionary *eventDataDictionary = [NSJSONSerialization JSONObjectWithData:[eventDataJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
        
        
        ETASDKLogInfo(@"ETA_CatalogView(%@) Event: %@", self.uuid, eventDataDictionary[@"eventName"]);
        
        [self eventTriggered:eventClass type:eventType data:eventDataDictionary];

        return NO;
    }
    else
    {
        ETASDKLogInfo(@"ETA_CatalogView(%@) Request URL is invalid: %@", self.uuid, request.URL);
    }
    return YES;
}


#pragma mark - Utility methods
- (BOOL) isInitialized
{
    return self.initState == ETA_CatalogView_InitState_Initialized;
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
            
            dataStr = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                            (CFStringRef)dataStr,
                                                                                            NULL,
                                                                                            (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                            kCFStringEncodingUTF8 ));
            
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
    
    return jsResponse;
}
- (void) performJSProxyMethodWithName:(NSString*)name data:(NSDictionary*)data
{
    [self performJSProxyMethodWithName:name data:data async:NO];
}
- (void) performJSProxyMethodWithName:(NSString*)name data:(NSDictionary*)data async:(BOOL)async
{
    __block NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    if (async)
    {
        dispatch_async(self.requestQ, ^{

            NSString* requestStr = [self jsRequestWithProxyMethodName:name data:data];
            if (ETASDK_IsLogLevel(ETASDK_LogLevel_Debug))
                ETASDKLogDebug(@"ETA_CatalogView(%@) Method '%@' parsing took %fsecs", self.uuid, name, [NSDate timeIntervalSinceReferenceDate] - start);
            
            start = [NSDate timeIntervalSinceReferenceDate];
            
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                if (!strongSelf)
                    return;
                
                [strongSelf performJSRequest:requestStr];
                
                if (ETASDK_IsLogLevel(ETASDK_LogLevel_Debug))
                    ETASDKLogDebug(@"ETA_CatalogView(%@) Method '%@' performing took %fsecs", self.uuid, name, [NSDate timeIntervalSinceReferenceDate] - start);
            });
        });
    }
    else
    {
        NSString* requestStr = [self jsRequestWithProxyMethodName:name data:data];
        
        if (ETASDK_IsLogLevel(ETASDK_LogLevel_Debug))
            ETASDKLogDebug(@"ETA_CatalogView(%@) Method '%@' parsing took %fsecs", self.uuid, name, [NSDate timeIntervalSinceReferenceDate] - start);

        start = [NSDate timeIntervalSinceReferenceDate];
        [self performJSRequest:requestStr];
        
        if (ETASDK_IsLogLevel(ETASDK_LogLevel_Debug))
            ETASDKLogDebug(@"ETA_CatalogView(%@) Method '%@' performing took %fsecs", self.uuid, name, [NSDate timeIntervalSinceReferenceDate] - start);

    }
}


- (NSDictionary*)geolocationDictionaryWithLocation:(CLLocation*)location radius:(NSNumber*)radius fromSensor:(BOOL)fromSensor
{
    NSMutableDictionary* geoDict = nil;
    // setup optional location data
    if (location)
    {
        geoDict = [@{} mutableCopy];
        geoDict[@"longitude"] = @(location.coordinate.longitude);
        geoDict[@"latitude"] = @(location.coordinate.latitude);
        geoDict[@"sensor"] = @(fromSensor);
        if (radius)
            geoDict[@"radius"] = radius;
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
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuidStringRef];
    CFRelease(uuidStringRef);
    
    return [uuid lowercaseString];
}

@end
