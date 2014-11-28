//
//  ETA+CatalogReaderStatsCollector.h
//  NativeCatalogReader
//
//  Created by Laurie Hufford on 26/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA.h"

#import "CatalogReaderPageStatisticEvent.h"

@interface ETA (CatalogReaderStatsCollector) <CatalogReaderPageStatisticCollectorProtocol>

- (void) collectPageStatisticsEvent:(CatalogReaderPageStatisticEvent *)statsEvent forCatalogID:(NSString*)catalogID;

@end
