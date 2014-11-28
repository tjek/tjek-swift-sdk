//
//  ETA_CatalogReaderDataFetcher.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ETA_CatalogReaderFetchedDataSource;
extern NSString * const kETA_CatalogReaderFetchedDataSource_ErrorDomain;
typedef NS_ENUM(NSInteger, ETA_CatalogReaderDataSource_ErrorCode) {
    ETA_CatalogReaderFetchedDataSource_ErrorInvalidResponseData,
};



@interface ETA_CatalogReaderDataFetcher : NSObject

- (instancetype) initWithFetchedDataSource:(id<ETA_CatalogReaderFetchedDataSource>)dataSource;


// An array of CatalorPageModel objects
- (void) fetchPagesForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pages, NSError* error))completion;

@end



#pragma mark - Fetched DataSource Protocol

@protocol ETA_CatalogReaderFetchedDataSource <NSObject>

@required
- (void) fetchPageImageDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pageImageData, NSError* error))completion;
- (void) fetchHotspotDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* hotspotData, NSError* error))completion;

@end