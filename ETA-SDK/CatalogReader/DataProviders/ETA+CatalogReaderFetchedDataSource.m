//
//  ETA+CatalogReaderData.m
//  NativeCatalogReader
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA+CatalogReaderFetchedDataSource.h"

@implementation ETA (CatalogReaderFetchedDataSource)

- (void) fetchPageImageDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pageImageData, NSError* error))completion
{   
    NSParameterAssert(completion);
    NSParameterAssert(catalogID);
    
    [self api:[ETA_API pathWithComponents:@[ETA_API.catalogs, catalogID, @"pages"]]
         type:ETARequestTypeGET
   parameters:nil
     useCache:YES
   completion:^(NSArray* jsonPageImageResponse, NSError *error, BOOL fromCache) {
       completion(jsonPageImageResponse, error);
   }];
}

- (void) fetchHotspotDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* hotspotData, NSError* error))completion
{
    NSParameterAssert(completion);
    NSParameterAssert(catalogID);

    
    [self api:[ETA_API pathWithComponents:@[ETA_API.catalogs, catalogID, @"hotspots"]]
         type:ETARequestTypeGET
   parameters:nil
     useCache:YES
   completion:^(NSArray* jsonPagesResponse, NSError *error, BOOL fromCache) {
       completion(jsonPagesResponse, error);
   }];
}

@end
