//
//  CatalogReaderDummyFetchedDataSource.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ETA_CatalogReaderDataFetcher.h"


@interface CatalogReaderDummyFetchedDataSource : NSObject <ETA_CatalogReaderFetchedDataSource>

- (instancetype) initWithDelay:(NSTimeInterval)delay;
@property (nonatomic, assign) NSTimeInterval delay;

- (void) fetchPageImageDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pageImageData, NSError* error))completion;
- (void) fetchHotspotDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* hotspotData, NSError* error))completion;


@end
