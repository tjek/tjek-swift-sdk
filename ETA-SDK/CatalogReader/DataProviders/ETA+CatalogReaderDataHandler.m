//
//  ETA+CatalogReaderDataHandler.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 01/12/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ETA+CatalogReaderDataHandler.h"

#import "ETA_CatalogReaderPageStatisticEvent.h"

#import "ETA_CatalogReaderView.h"
#import "ETA_CatalogHotspotModel.h"
#import "ETA_CatalogPageModel.h"


@implementation ETA (CatalogReaderDataHandler)


#pragma mark - Data Fetching

- (void) fetchPagesForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pages, NSError* error))completion
{
    NSParameterAssert(completion);
    NSParameterAssert(catalogID);
    
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    __block BOOL hasFetchedPages = NO;
    __block NSArray* fetchedPageImageData = nil;
    __block NSError* pageImageDataFetchError = nil;
    
    __block BOOL hasFetchedHotspots = NO;
    __block NSArray* fetchedHotspotData = nil;
    __block NSError* hotspotDataFetchError = nil;
    
    // what to do when both the fetches complete
    void (^maybeHandleCompletion)() = ^() {
        
        // both havnt completed yet - ignore
        if (!hasFetchedHotspots || !hasFetchedPages)
        {
            return;
        }
        
        __block NSError* error = pageImageDataFetchError ?: hotspotDataFetchError;
        
        // there was an error while fetching - eject
        if (error)
        {
            ETASDKLogError(@"Error Fetching Page Data: %@", error);
            completion(nil, error);
            return;
        }
        
        
        
        NSMutableArray* pages = [NSMutableArray arrayWithCapacity:fetchedPageImageData.count];
        
        // go through all the pages, creating page model objects and saving in an array, indexed by page number
        [fetchedPageImageData enumerateObjectsUsingBlock:^(NSDictionary* pageImageData, NSUInteger pageIndex, BOOL *stop) {
            
            ETA_CatalogPageModel* page = nil;
            if ([pageImageData isKindOfClass:NSDictionary.class])
            {
                NSMutableDictionary* urlsBySize = [NSMutableDictionary dictionary];
                [pageImageData enumerateKeysAndObjectsUsingBlock:^(NSString* size, NSString* urlString, BOOL *stop) {
                    NSURL* url = nil;
                    if ([urlString isKindOfClass:NSString.class])
                        url = [NSURL URLWithString:urlString];
                    else if ([urlString isKindOfClass:NSURL.class])
                        url = (NSURL*)urlString;
                    
                    urlsBySize[size] = url;
                }];
                page = [ETA_CatalogPageModel catalogPageWithPageIndex:pageIndex imageURLsBySize:urlsBySize];
            }
            
            if (!page)
            {
                error = [NSError errorWithDomain:kETA_CatalogReader_ErrorDomain code:ETA_CatalogReader_ErrorInvalidResponseData userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Page Data is invalid", nil)}];
                *stop = YES;
                return;
            }
            
            [pages addObject:page];
        }];
        
        
        if (error)
        {
            ETASDKLogError(@"An error occurred while parsing one of the pages - can't proceed");
            completion(nil, error);
            return;
        }
        
        
        
        // go through all the hotspot data, adding the hotspot object to the page object
        [fetchedHotspotData enumerateObjectsUsingBlock:^(NSDictionary* hotspotData, NSUInteger idx, BOOL *stop) {
            ETA_CatalogHotspotModel* hotspot = nil;
            
            if ([hotspotData isKindOfClass:ETA_CatalogHotspotModel.class])
            {
                hotspot = (ETA_CatalogHotspotModel*)hotspotData;
            }
            else if ([hotspotData isKindOfClass:NSDictionary.class])
            {
                hotspot = [MTLJSONAdapter modelOfClass:ETA_CatalogHotspotModel.class fromJSONDictionary:hotspotData error:NULL];
            }
            
            if (!hotspot)
            {
                error = [NSError errorWithDomain:kETA_CatalogReader_ErrorDomain code:ETA_CatalogReader_ErrorInvalidResponseData userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Hotspot Data is invalid", nil)}];
                *stop = YES;
                return;
            }
            
            
            // find the pages that the hotspot is on
            NSIndexSet* activePageIndexes = [hotspot activePageIndexes];
            [activePageIndexes enumerateIndexesUsingBlock:^(NSUInteger pageIndex, BOOL *stop) {
                if (pageIndex < pages.count)
                {
                    ETA_CatalogPageModel* page = pages[pageIndex];
                    [page addHotspot:hotspot];
                }
            }];
            
        }];
        
        
        if (error)
        {
            ETASDKLogError(@"An error occurred while parsing one of the hotspots - can't proceed");
            completion(nil, error);
            return;
        }
        
        
        
        NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
        ETASDKLogInfo(@"Both Fetches Completed (%.4f secs) - %tu pages", duration, pages.count);
        
        completion(pages, error);
    };
    
    
    
    
    dispatch_queue_t fetchCompletionQ = dispatch_get_global_queue(0, 0);
    
    [self _fetchPageImageDataForCatalogID:catalogID completion:^(NSArray *pageImageData, NSError *error) {
        dispatch_async(fetchCompletionQ, ^{
            fetchedPageImageData = pageImageData;
            pageImageDataFetchError = error;
            
            hasFetchedPages = YES;
            maybeHandleCompletion();
        });
    }];
    
    [self _fetchHotspotDataForCatalogID:catalogID completion:^(NSArray *hotspotData, NSError *error) {
        dispatch_async(fetchCompletionQ, ^{
            fetchedHotspotData = hotspotData;
            hotspotDataFetchError = error;
            
            hasFetchedHotspots = YES;
            maybeHandleCompletion();
        });
    }];
}

- (void) _fetchPageImageDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pageImageData, NSError* error))completion
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

- (void) _fetchHotspotDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* hotspotData, NSError* error))completion
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







#pragma mark - Data Collection

- (void) collectPageStatisticsEvent:(ETA_CatalogReaderPageStatisticEvent *)statsEvent forCatalogID:(NSString*)catalogID
{
    NSDictionary* params = [statsEvent toDictionary];
    
    NSParameterAssert(params);
    
    
    ETASDKLogInfo(@"COLLECTING %@ %@", catalogID, statsEvent);
    
    [self api:[ETA_API pathWithComponents:@[ETA_API.catalogs, catalogID, @"collect"]]
         type:ETARequestTypePOST
   parameters:params
     useCache:NO
   completion:^(NSArray* jsonCollectResponse, NSError *error, BOOL fromCache) {
       if (error)
       {
           ETASDKLogError(@"Unable to collect %@ %@", statsEvent, error);
       }
   }];
}

@end
