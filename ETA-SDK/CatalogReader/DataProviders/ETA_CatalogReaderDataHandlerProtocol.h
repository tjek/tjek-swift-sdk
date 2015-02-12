//
//  ETA_CatalogReaderDataHandlerProtocol.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 01/12/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ETA_CatalogReaderPageStatisticEvent.h"

@protocol ETA_CatalogReaderDataHandlerProtocol <NSObject>

#pragma mark - Data Fetching

// An array of CatalogPageModel objects (containing hotspot data)
- (void) fetchPagesForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pages, NSError* error))completion;


#pragma mark - Data Collection
- (void) collectPageStatisticsEvent:(ETA_CatalogReaderPageStatisticEvent *)statsEvent forCatalogID:(NSString*)catalogID;

@end
