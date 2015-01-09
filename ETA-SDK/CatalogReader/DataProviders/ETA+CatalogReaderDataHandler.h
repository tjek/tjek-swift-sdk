//
//  ETA+CatalogReaderDataHandler.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 01/12/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ETA.h"

#import "ETA_CatalogReaderDataHandlerProtocol.h"



// Error handling
extern NSString * const kETA_CatalogReaderDataHandler_ErrorDomain;

typedef NS_ENUM(NSInteger, ETA_CatalogReaderDataHandler_ErrorCode) {
    ETA_CatalogReaderDataHandler_ErrorInvalidResponseData,
    ETA_CatalogReaderDataHandler_ErrorOutdatedResponse,
};



@interface ETA (CatalogReaderDataHandler) <ETA_CatalogReaderDataHandlerProtocol>

- (void) fetchPagesForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pages, NSError* error))completion;

- (void) collectPageStatisticsEvent:(ETA_CatalogReaderPageStatisticEvent *)statsEvent forCatalogID:(NSString*)catalogID;
- (void) collectCatalogOpeningStatisticForCatalogID:(NSString*)catalogID;

@end
