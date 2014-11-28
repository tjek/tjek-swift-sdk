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


// Note - DO NOT set this property. It will assert, as the SDKCatalogReaderView is its own datasource
@property (nonatomic, weak) id<ETA_VersoPagedViewDataSource> dataSource;





//- (instancetype) initWithCatalog:(ETA_Catalog*)catalog pageNumber:(NSUInteger)pageNumber;
//- (instancetype) initWithCatalogID:(NSString*)catalogID sdk:(ETA*)sdk;
//- (instancetype) initWithETA:(ETA*)sdk baseURL:(NSURL*)baseURL;


//@property (nonatomic, readonly, assign) NSUInteger currentPage;
//@property (nonatomic, readonly, assign) NSUInteger pageCount;
//@property (nonatomic, readonly, assign) CGFloat pageProgress;

@end


