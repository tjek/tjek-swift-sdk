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

// Views
#import "ETA_VersoPageSpreadCell.h"


@interface ETA_VersoPagedView (Subclass)

@property (nonatomic, strong) UICollectionView* collectionView;
@property (nonatomic, strong) NSIndexPath* currentIndexPath;

- (void) didChangeVisiblePageIndexRangeFrom:(NSRange)prevRange;
- (void) didTapLocation:(CGPoint)tapLocation normalizedPoint:(CGPoint)normalizedPoint onPageIndex:(NSUInteger)pageIndex;
- (void) didLongPressLocation:(CGPoint)longPressLocation normalizedPoint:(CGPoint)normalizedPoint onPageIndex:(NSUInteger)pageIndex;
- (void) didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex;
- (UIColor*) backgroundColorAtPageIndex:(NSUInteger)pageIndex;

- (void) willBeginZooming:(CGFloat)zoomScale;
- (void) didZoom:(CGFloat)zoomScale;
- (void) didEndZooming:(CGFloat)zoomScale;

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
    if (!fetchingCatalogID)
        return;
    
    self.isFetchingData = YES;
    
    // send started fetching delegate callback
    if ([self.delegate respondsToSelector:@selector(catalogReaderViewDidStartFetchingData:)])
    {
        [self.delegate catalogReaderViewDidStartFetchingData:self];
    }
    
    __weak __typeof(self) weakSelf = self;
    [self.dataHandler fetchPagesForCatalogID:fetchingCatalogID completion:^(NSArray *pages, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError* fetchError = error;
            
            // the catalogID hasnt changed since we started the fetch - success
            if ([fetchingCatalogID isEqualToString:weakSelf.catalogID])
            {
                weakSelf.isFetchingData = NO;
                
                if (error)
                {
                    weakSelf.pageObjects = nil;
                }
                else
                {
                    //update the data source info
                    weakSelf.pageObjects = pages;
                }
                
                [weakSelf reloadPages];
            }
            else
            {
                //TODO: make an out-of-date fetch error, to send to the delegate callback
                fetchError = [NSError errorWithDomain:@"" code:0 userInfo:@{}];
            }
            
            // trigger fetched event delegate callback
            if ([self.delegate respondsToSelector:@selector(catalogReaderViewDidFinishFetchingData:error:)])
            {
                [self.delegate catalogReaderViewDidFinishFetchingData:self error:error];
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
        ETA_VersoPageSpreadCell* pageView = (ETA_VersoPageSpreadCell*)[self.collectionView cellForItemAtIndexPath:self.currentIndexPath];
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
    
    ETA_CatalogReaderPageStatisticEventOrientation orientation = self.bounds.size.width > self.bounds.size.height ? ETA_CatalogReaderPageStatisticEventOrientation_Landscape : ETA_CatalogReaderPageStatisticEventOrientation_Portrait;
    NSRange pageRange = self.visiblePageIndexRange;
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

- (void) didChangeVisiblePageIndexRangeFrom:(NSRange)prevRange
{
    // finish any existing page view/zoom stats
    [self _collectAllCurrentPageStatsEvents];
    
    
    [self _startPageViewStatsEventIfImageLoaded];

    [super didChangeVisiblePageIndexRangeFrom:prevRange];
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
}







#pragma mark - DataSource

- (id<ETA_VersoPagedViewDataSource>) dataSource
{
    return self;
}
- (void) setDataSource:(id<ETA_VersoPagedViewDataSource>)dataSource
{
    NSAssert(NO, NSLocalizedString(@"Datasource may not be overridden in SDK version", nil));
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
        NSString* offerID = nil;
        
        if ([hotspot isKindOfClass:ETA_CatalogOfferHotspotModel.class])
        {
            offerID = ((ETA_CatalogOfferHotspotModel*)hotspot).offer;
        }
        
        if (!offerID)
            continue;

        //TODO: convert to standard normalized coords
        CGRect boundingRect = [hotspot boundingRectForPageIndex:pageIndex];
        if (CGRectIsNull(boundingRect) == NO)
        {
            hotspotRects[offerID] = [NSValue valueWithCGRect:boundingRect];
        }
    }
    return hotspotRects;
}






#pragma mark - Utilities

- (ETA_CatalogPageModel*) _pageAtIndex:(NSUInteger)pageIndex
{
    if (pageIndex >= self.pageObjects.count)
        return nil;
    
    return self.pageObjects[pageIndex];
}

- (NSArray*) _hotspotsAtNormalizedPoint:(CGPoint)normalizedPoint onPageIndex:(NSUInteger)pageIndex
{
    NSMutableArray* matchingHotspots = [NSMutableArray array];
    
    NSArray* hotspots = [[self _pageAtIndex:pageIndex] allHotspots];
    [hotspots enumerateObjectsUsingBlock:^(ETA_CatalogOfferHotspotModel* hotspot, NSUInteger idx, BOOL *stop) {
        CGRect hotspotRect = [hotspot boundingRectForPageIndex:pageIndex];
        
        if (CGRectContainsPoint(hotspotRect, normalizedPoint))
        {
            [matchingHotspots addObject:hotspot];
        }
    }];
    
    return matchingHotspots;
}






@end
