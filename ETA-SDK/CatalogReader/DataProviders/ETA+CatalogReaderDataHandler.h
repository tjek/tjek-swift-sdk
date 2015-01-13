//
//  ETA+CatalogReaderDataHandler.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 01/12/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ETA.h"

#import "ETA_CatalogReaderDataHandlerProtocol.h"




@interface ETA (CatalogReaderDataHandler) <ETA_CatalogReaderDataHandlerProtocol>

- (void) fetchPagesForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pages, NSError* error))completion;

- (void) collectPageStatisticsEvent:(ETA_CatalogReaderPageStatisticEvent *)statsEvent forCatalogID:(NSString*)catalogID;

@end
