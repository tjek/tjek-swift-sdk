//
//  ETA+CatalogReaderData.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA.h"

#import "ETA_CatalogReaderDataFetcher.h"


@interface ETA (CatalogReaderFetchedDataSource) <ETA_CatalogReaderFetchedDataSource>

- (void) fetchPageImageDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pageImageData, NSError* error))completion;
- (void) fetchHotspotDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* hotspotData, NSError* error))completion;

@end

