//
//  ETA+CatalogReaderStatsCollector.m
//  NativeCatalogReader
//
//  Created by Laurie Hufford on 26/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA+CatalogReaderStatsCollector.h"

@implementation ETA (CatalogReaderStatsCollector)

- (void) collectPageStatisticsEvent:(CatalogReaderPageStatisticEvent *)statsEvent forCatalogID:(NSString*)catalogID
{
    NSDictionary* params = [statsEvent toDictionary];
    
    NSParameterAssert(params);
    
    
    NSLog(@"COLLECTING %@ %@", catalogID, statsEvent);
    
    [self api:[ETA_API pathWithComponents:@[ETA_API.catalogs, catalogID, @"collect"]]
         type:ETARequestTypePOST
   parameters:params
     useCache:NO
   completion:^(NSArray* jsonCollectResponse, NSError *error, BOOL fromCache) {
       if (error)
       {
           NSLog(@"Unable to collect %@ %@", statsEvent, error);
       }
   }];
}

@end
