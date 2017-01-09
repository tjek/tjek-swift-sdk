//
//  ETA_CatalogReaderView.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 24/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_CatalogReaderView.h"

#import "ETA+CatalogReaderDataHandler.h"


// Model
#import "ETA_CatalogPageModel.h"
#import "ETA_CatalogHotspotModel.h"
#import "ETA_Offer.h"


// Views
#import "ETA_VersoPageSpreadCell.h"


NSString * const kETA_CatalogReader_ErrorDomain = @"kETA_CatalogReader_ErrorDomain";


@interface ETA_VersoPagedView (Subclass)

@property (nonatomic, strong) UICollectionView* collectionView;
- (ETA_VersoPageSpreadCell*) _currentPageSpreadCell;

- (void) beganScrollingFrom:(NSRange)currentPageIndexRange;
- (void) beganScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange;
- (void) finishedScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange;

- (void) didBeginTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;
- (void) didFinishTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;

- (void) didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;
- (void) didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;
- (void) didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex;
- (UIColor*) backgroundColorAtPageIndex:(NSUInteger)pageIndex;

- (void) willBeginZooming:(CGFloat)zoomScale;
- (void) didZoom:(CGFloat)zoomScale;
- (void) didEndZooming:(CGFloat)zoomScale;

- (void) willBeginDisplayingOutro;
- (void) didEndDisplayingOutro;

@end


@interface ETA_CatalogReaderView () <ETA_VersoPagedViewDataSource>

@property (nonatomic, strong) id<ETA_CatalogReaderDataHandlerProtocol> dataHandler;


// stats collecting
@property (nonatomic, strong) ETA_CatalogReaderPageStatisticEvent* currentViewStatsEvent;
@property (nonatomic, strong) ETA_CatalogReaderPageStatisticEvent* currentZoomStatsEvent;
@property (nonatomic, strong) NSString* statsSessionID; // the UUID of the current viewing session. generated on first request

// the user must open a catalog for the data to fetched. -startReading and -stopReading will change this value
@property (nonatomic, assign, getter=isCatalogOpen) BOOL catalogOpen;


@property (nonatomic, strong) NSArray* pageObjects;
@property (nonatomic, assign) BOOL isFetchingData;


@property (nonatomic, strong) NSError* lastFetchingError;

@end



@implementation ETA_CatalogReaderView

@dynamic delegate;

+ (instancetype) catalogReader
{
    return [self catalogReaderWithSDK:nil];
}

+ (instancetype) catalogReaderWithSDK:(ETA*)SDK
{
    return [[self alloc] initWithFrame:CGRectZero SDK:SDK];
}

- (instancetype) initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame SDK:nil];
}
- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithCoder:aDecoder SDK:nil];
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder SDK:(ETA *)SDK
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self _commonCatalogReaderViewInitWithSDK:SDK];
    }
    return self;
}
- (instancetype) initWithFrame:(CGRect)frame SDK:(ETA *)SDK
{
    if (self = [super initWithFrame:frame])
    {
        [self _commonCatalogReaderViewInitWithSDK:SDK];
    }
    return self;
}


- (void) _commonCatalogReaderViewInitWithSDK:(ETA*)SDK
{
    _catalogOpen = NO;
    _isFetchingData = NO;
    _pageObjects = nil;
    
    // default to the ETA-SDK singleton
    if (!SDK)
        SDK = ETA.SDK;
    
    self.dataHandler = SDK;
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    _dataHandler = nil;
    _catalogID = nil;
}




#pragma mark - Notifications

// the app is going into the background - collect any pending stats
- (void) _applicationWillResignActive
{
    [self _collectAllCurrentPageStatsEvents];
}

// the app is coming into the foreground, start a new page view if the catalog is open, and there are images for the current page
- (void) _applicationDidBecomeActive
{
    [self _startPageViewStatsEventIfImageLoaded];
}






#pragma mark - Catalog Fetching

- (void) setCatalogID:(NSString *)catalogID
{
    if (_catalogID == catalogID || [_catalogID isEqualToString:catalogID])
        return;
    
    _catalogID = catalogID;
    
    
    
    //collect any pending fetch requests
    [self _collectAllCurrentPageStatsEvents];
    
    // start a new stats session
    self.statsSessionID = nil;
    
    // invalidate fetched page objects
    self.pageObjects = nil;
    
    // stop active fetching events
    self.isFetchingData = NO;
    
    // if the catalog is already open, trigger a refetch
    if (self.isCatalogOpen)
    {
        [self fetchCatalogData];
    }
    
}

- (void) startReading
{
    if (self.isCatalogOpen)
        return;
    
    ETASDKLogInfo(@"Start Reading");
    
    self.catalogOpen = YES;
    
    // we dont have any data, and we are not currently fetching any, so start fetching
    if (!self.pageObjects && !self.isFetchingData)
    {
        [self fetchCatalogData];
    }
    // we already have data - so start a page view stats event for the current page
    else
    {
        [self _startPageViewStatsEventIfImageLoaded];
    }
}

- (void) stopReading
{
    ETASDKLogInfo(@"Stop Reading");
    
    // just collect any pending events
    [self _collectAllCurrentPageStatsEvents];
    
    // mark as closed
    self.catalogOpen = NO;
}




- (void) fetchCatalogData
{
    // dont fetch if we are in the process of fetching
    if (self.isFetchingData)
        return;
    
    // dont fetch if we dont have a catalogID
    NSString* fetchingCatalogID = self.catalogID;
    if (!fetchingCatalogID) {
        [self stopReading];
        return;
    }
    
    self.isFetchingData = YES;
    
    // send started fetching delegate callback
    if ([self.delegate respondsToSelector:@selector(catalogReaderViewDidStartFetchingData:)])
    {
        [self.delegate catalogReaderViewDidStartFetchingData:self];
    }
    
    __weak __typeof(self) weakSelf = self;
    [self.dataHandler fetchPagesForCatalogID:fetchingCatalogID completion:^(NSArray *pages, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;

            NSError* fetchError = error;
            
            // the catalogID hasnt changed since we started the fetch - success
            if ([fetchingCatalogID isEqualToString:strongSelf.catalogID])
            {
                strongSelf.isFetchingData = NO;
                
                if (fetchError)
                {
                    strongSelf.pageObjects = nil;
                    [strongSelf stopReading];
                }
                else
                {
                    //update the data source info
                    strongSelf.pageObjects = pages;
                }
                
                [strongSelf reloadPages];
            }
            else
            {
                fetchError = [NSError errorWithDomain:kETA_CatalogReader_ErrorDomain code:ETA_CatalogReader_ErrorOutdatedResponse userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"The fetched data is out of data - the catalog ID has changed since the fetch started", nil)}];
            }
            
            // trigger fetched event delegate callback
            if ([strongSelf.delegate respondsToSelector:@selector(catalogReaderViewDidFinishFetchingData:error:)])
            {
                [strongSelf.delegate catalogReaderViewDidFinishFetchingData:strongSelf error:fetchError];
            }
        });
    }];
}








#pragma mark - Stats


- (BOOL) _shouldStartStatsEvent
{
    return self.isCatalogOpen && self.window != nil;
}

- (void) _startPageViewStatsEventIfImageLoaded
{
    if ([self _shouldStartStatsEvent])
    {
        
        ETA_VersoPageSpreadCell* pageView = [self _currentPageSpreadCell];
        if ([pageView anyImagesLoaded])
        {
            [self _startPageViewStatsEvent]; // start the page if it already has an image loaded
        }
    }
}

- (void) _startPageViewStatsEvent
{
    // already viewing a page - no-op (must collect first)
    if (self.currentViewStatsEvent)
    {
        return;
    }
    
    NSRange pageRange = self.visiblePageIndexRange;
    if (pageRange.location == NSNotFound || pageRange.length == 0)
    {
        return;
    }
    
    ETA_CatalogReaderPageStatisticEventOrientation orientation = self.bounds.size.width > self.bounds.size.height ? ETA_CatalogReaderPageStatisticEventOrientation_Landscape : ETA_CatalogReaderPageStatisticEventOrientation_Portrait;
    
    pageRange.location ++; // as we use index, and the stats system uses page number
    
    self.currentViewStatsEvent = [[ETA_CatalogReaderPageStatisticEvent alloc] initWithType:ETA_CatalogReaderPageStatisticEventType_View
                                                                           orientation:orientation
                                                                             pageRange:pageRange
                                                                         viewSessionID:self.statsSessionID];
    [self.currentViewStatsEvent start];
}

- (void) _startZoomingStatsEvent
{
    // already zooming - no-op
    if (self.currentZoomStatsEvent)
    {
        return;
    }
    
    
    [self.currentViewStatsEvent pause];

    
    ETA_CatalogReaderPageStatisticEventOrientation orientation = self.bounds.size.width > self.bounds.size.height ? ETA_CatalogReaderPageStatisticEventOrientation_Landscape : ETA_CatalogReaderPageStatisticEventOrientation_Portrait;
    NSRange pageRange = self.visiblePageIndexRange;
    pageRange.location ++; // as we use index, and the stats system uses page number
    
    self.currentZoomStatsEvent = [[ETA_CatalogReaderPageStatisticEvent alloc] initWithType:ETA_CatalogReaderPageStatisticEventType_Zoom
                                                                           orientation:orientation
                                                                             pageRange:pageRange
                                                                         viewSessionID:self.statsSessionID];
    [self.currentZoomStatsEvent start];
}
- (void) _stopZoomingStatsEvent
{
    if (self.currentZoomStatsEvent)
    {
        [self.dataHandler collectPageStatisticsEvent:self.currentZoomStatsEvent forCatalogID:self.catalogID];
        self.currentZoomStatsEvent = nil;
    }
    
    // restart the view event
    [self.currentViewStatsEvent start];
}

- (void) _collectAllCurrentPageStatsEvents
{
    //first finish the zoom event, if we have one
    if (self.currentZoomStatsEvent)
    {
        [self.dataHandler collectPageStatisticsEvent:self.currentZoomStatsEvent forCatalogID:self.catalogID];
        self.currentZoomStatsEvent = nil;
    }
    
    //first finish the zoom event, if we have one
    if (self.currentViewStatsEvent)
    {
        [self.dataHandler collectPageStatisticsEvent:self.currentViewStatsEvent forCatalogID:self.catalogID];
        self.currentViewStatsEvent = nil;
    }
}


- (NSString*) statsSessionID
{
    if (!_statsSessionID)
    {
        // generate a UUID
        CFUUIDRef uuidRef = CFUUIDCreate(NULL);
        CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
        CFRelease(uuidRef);
        NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuidStringRef];
        CFRelease(uuidStringRef);
        
        _statsSessionID = [uuid lowercaseString];
    }
    return _statsSessionID;
}



#pragma mark - Subclassed Methods
- (void) beganScrollingFrom:(NSRange)currentPageIndexRange
{
    [super beganScrollingFrom:currentPageIndexRange];
}
- (void) beganScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    [super beganScrollingIntoNewPageIndexRange:newPageIndexRange from:previousPageIndexRange];
}
- (void) finishedScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    // has the range changed
    BOOL doCollect = (newPageIndexRange.location != previousPageIndexRange.location || newPageIndexRange.length != previousPageIndexRange.length);
    
    // even if the page range didnt change, check if the orientation changed
    if (!doCollect && self.currentViewStatsEvent)
    {
        ETA_CatalogReaderPageStatisticEventOrientation orientation = self.bounds.size.width > self.bounds.size.height ? ETA_CatalogReaderPageStatisticEventOrientation_Landscape : ETA_CatalogReaderPageStatisticEventOrientation_Portrait;
     
        doCollect = (self.currentViewStatsEvent.orientation != orientation);
    }

    
    if (doCollect)
    {
        // finish any existing page view/zoom stats
        [self _collectAllCurrentPageStatsEvents];
        
        // start a new page stats event, if it is ready
        [self _startPageViewStatsEventIfImageLoaded];
    }
    
    [super finishedScrollingIntoNewPageIndexRange:newPageIndexRange from:previousPageIndexRange];
}

- (void) willBeginDisplayingOutro
{
    [super willBeginDisplayingOutro];
}

- (void) didEndDisplayingOutro
{
    [super didEndDisplayingOutro];
}

- (void) didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex
{
    if ([self _shouldStartStatsEvent])
    {
        // if not the zoom image, and is currently visible, then start a page view
        if (!isZoomImage && NSLocationInRange(pageIndex, self.visiblePageIndexRange))
        {
            [self _startPageViewStatsEvent]; // no-op if there is already an active page stat
        }
    }
    
    [super didSetImage:image isZoomImage:isZoomImage onPageIndex:pageIndex];
}

- (void)didZoom:(CGFloat)zoomScale
{
    [super didZoom:zoomScale];
    
    if ([self.delegate respondsToSelector:@selector(catalogReaderView:didZoom:)])
    {
        [self.delegate catalogReaderView:self didZoom:zoomScale];
    }
}

- (void) didEndZooming:(CGFloat)zoomScale
{
    if ([self _shouldStartStatsEvent])
    {
        // zoomed in
        if (zoomScale > 1.2)
        {
            [self _startZoomingStatsEvent];
        }
        else
        {
            [self _stopZoomingStatsEvent];
        }
    }
    
    [super didEndZooming:zoomScale];
    
    if ([self.delegate respondsToSelector:@selector(catalogReaderView:didFinishZooming:)])
    {
        [self.delegate catalogReaderView:self didFinishZooming:zoomScale];
    }    
}

- (void) didBeginTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(catalogReaderView:didBeginTouchingLocation:onPageIndex:hittingHotspots:)])
    {
        NSArray* hotspots = [self _hotspotsOnPageIndex:pageIndex matchingKeys:hotspotKeys];
        
        [self.delegate catalogReaderView:self didBeginTouchingLocation:tapLocation onPageIndex:pageIndex hittingHotspots:hotspots];
    }
    
    [super didBeginTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys];
}

- (void) didFinishTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(catalogReaderView:didFinishTouchingLocation:onPageIndex:hittingHotspots:)])
    {
        NSArray* hotspots = [self _hotspotsOnPageIndex:pageIndex matchingKeys:hotspotKeys];
        
        [self.delegate catalogReaderView:self didFinishTouchingLocation:tapLocation onPageIndex:pageIndex hittingHotspots:hotspots];
    }
    
    [super didFinishTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys];
}


- (void) didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(catalogReaderView:didTapLocation:onPageIndex:hittingHotspots:)])
    {
        NSArray* hotspots = [self _hotspotsOnPageIndex:pageIndex matchingKeys:hotspotKeys];
        
        [self.delegate catalogReaderView:self didTapLocation:tapLocation onPageIndex:pageIndex hittingHotspots:hotspots];
    }
    
    [super didTapLocation:tapLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
}

- (void) didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray *)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(catalogReaderView:didLongPressLocation:onPageIndex:hittingHotspots:)])
    {
        NSArray* hotspots = [self _hotspotsOnPageIndex:pageIndex matchingKeys:hotspotKeys];
        
        [self.delegate catalogReaderView:self didLongPressLocation:longPressLocation onPageIndex:pageIndex hittingHotspots:hotspots];
    }
    [super didLongPressLocation:longPressLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
}

#pragma mark - DataSource

- (id<ETA_VersoPagedViewDataSource>) dataSource
{
    return self;
}
- (void) setDataSource:(id<ETA_VersoPagedViewDataSource>)dataSource
{
    ETASDKLogWarn(@"ETA_CatalogReaderView DataSource may not be set");
}




- (NSUInteger) numberOfPagesInVersoPagedView:(ETA_VersoPagedView *)versoPagedView
{
    return self.pageObjects.count;
}

- (NSURL*) versoPagedView:(ETA_VersoPagedView *)versoPagedView imageURLForPageIndex:(NSUInteger)pageIndex withMaxSize:(CGSize)maxPageSize isZoomImage:(BOOL)isZoomImage
{
    ETA_CatalogPageModel* page = [self _pageAtIndex:pageIndex];
    if (!page)
    {
        return nil;
    }
    
    
    /*
     thumb: 177 x 212
     view: 712 x 1004 / 768 x 768
     zoom: 1068 x 1506 / 1152 x 1152
     */
    
    NSString* sizeName = nil;
    
    
    // TODO: check if they are on fast wifi
    BOOL onFastWifi = NO;
    
    CGFloat maxPixelDimension = MAX(maxPageSize.width, maxPageSize.height) * UIScreen.mainScreen.scale;
    BOOL needBigImage = maxPixelDimension > 1500;
    
    if (isZoomImage || (needBigImage && onFastWifi))
    {
        sizeName = @"zoom";
    }
    else
    {
        sizeName = @"view";
    }
    
    
    NSURL* imageURL = [page imageURLForSizeName:sizeName];
    
    return imageURL;
}

- (NSDictionary*) versoPagedView:(ETA_VersoPagedView *)versoPagedView hotspotRectsForPageIndex:(NSUInteger)pageIndex
{
    ETA_CatalogPageModel* page = [self _pageAtIndex:pageIndex];
    if (!page)
    {
        return nil;
    }
    
    NSArray* hotspots = [page allHotspots];
    
    NSMutableDictionary* hotspotRects = [NSMutableDictionary dictionary];
    for (ETA_CatalogHotspotModel* hotspot in hotspots)
    {
        NSString* hotspotKey = nil;
        
        if ([hotspot isKindOfClass:ETA_CatalogOfferHotspotModel.class])
        {
            ETA_Offer* offer = ((ETA_CatalogOfferHotspotModel*)hotspot).offer;
            hotspotKey = offer.uuid;
        }
        
        if (!hotspotKey)
            continue;

        
        //TODO: convert to standard normalized coords
        CGRect boundingRect = [hotspot boundingRectForPageIndex:pageIndex];
        if (CGRectIsNull(boundingRect) == NO)
        {
            hotspotRects[hotspotKey] = [NSValue valueWithCGRect:boundingRect];
        }
    }
    return hotspotRects;
}

- (BOOL) versoPagedView:(ETA_VersoPagedView*)versoPagedView hotspotRectsNormalizedByWidthForPageIndex:(NSUInteger)pageIndex
{
    return YES;
}




#pragma mark - Utilities

- (ETA_CatalogPageModel*) _pageAtIndex:(NSUInteger)pageIndex
{
    if (pageIndex >= self.pageObjects.count)
        return nil;
    
    return self.pageObjects[pageIndex];
}


- (NSArray*) _hotspotsOnPageIndex:(NSUInteger)pageIndex matchingKeys:(NSArray*)matchingKeys
{
    ETA_CatalogPageModel* page = [self _pageAtIndex:pageIndex];
    if (!page)
    {
        return nil;
    }
    
    if (!matchingKeys.count)
        return @[];
    
    NSArray* hotspots = [page allHotspots];
    if (!matchingKeys)
        return hotspots;
    
    NSMutableArray* matchingHotspots = [NSMutableArray array];
    
    for (ETA_CatalogHotspotModel* hotspot in hotspots)
    {
        NSString* hotspotKey = nil;
        
        if ([hotspot isKindOfClass:ETA_CatalogOfferHotspotModel.class])
        {
            ETA_Offer* offer = ((ETA_CatalogOfferHotspotModel*)hotspot).offer;
            hotspotKey = offer.uuid;
        }
        
        if (!hotspotKey)
            continue;
        
        if ([matchingKeys containsObject:hotspotKey])
            [matchingHotspots addObject:hotspot];
    }
    return matchingHotspots;
}


@end
