//
//  ETA_CatalogReaderView.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 24/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_VersoPagedView.h"

@class ETA;
@class ETA_CatalogReaderView;

@protocol ETA_CatalogReaderViewDelegate <ETA_VersoPagedViewDelegate>

@optional

- (void) catalogReaderViewDidStartFetchingData:(ETA_CatalogReaderView *)catalogReaderView;
- (void) catalogReaderViewDidFinishFetchingData:(ETA_CatalogReaderView *)catalogReaderView error:(NSError*)error;


- (void) catalogReaderView:(ETA_CatalogReaderView *)catalogReaderView didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspots:(NSArray*)hotspots;
- (void) catalogReaderView:(ETA_CatalogReaderView *)catalogReaderView didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspots:(NSArray*)hotspots;

- (void) catalogReaderView:(ETA_CatalogReaderView *)catalogReaderView didFinishZooming:(CGFloat)zoomScale;
- (void) catalogReaderView:(ETA_CatalogReaderView *)catalogReaderView didZoom:(CGFloat)zoomScale;


@end



@interface ETA_CatalogReaderView : ETA_VersoPagedView


// Uses the ETA.SDK singleton
+ (instancetype) catalogReader;
+ (instancetype) catalogReaderWithSDK:(ETA*)SDK;

@property (nonatomic, copy) NSString* catalogID;




- (void) startReading;
- (void) stopReading;



#pragma mark - Data Fetching

@property (nonatomic, assign, readonly) BOOL isFetchingData;
@property (nonatomic, strong, readonly) NSArray* pageObjects;




@property (nonatomic, weak) id<ETA_CatalogReaderViewDelegate> delegate;


// Note - DO NOT try to set this property. It is a no-op
@property (nonatomic, weak) id<ETA_VersoPagedViewDataSource> dataSource;



@end


