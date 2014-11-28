//
//  ETA_CatalogReaderDataFetcher.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_CatalogReaderDataFetcher.h"

// Model
#import "ETA_CatalogHotspotModel.h"
#import "ETA_CatalogPageModel.h"

NSString * const kETA_CatalogReaderFetchedDataSource_ErrorDomain = @"kETA_CatalogReaderFetchedDataSource_ErrorDomain";

@interface ETA_CatalogReaderDataFetcher()

@property (nonatomic, strong) id<ETA_CatalogReaderFetchedDataSource> dataSource;

@end


@implementation ETA_CatalogReaderDataFetcher

- (instancetype) initWithFetchedDataSource:(id<ETA_CatalogReaderFetchedDataSource>)dataSource
{
    NSParameterAssert(dataSource);
    if (self = [super init])
    {
        _dataSource = dataSource;
    }
    return self;
}



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
//            NSLog(@"Error Fetching Page data! %@", error);
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
                error = [NSError errorWithDomain:kETA_CatalogReaderFetchedDataSource_ErrorDomain code:ETA_CatalogReaderFetchedDataSource_ErrorInvalidResponseData userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Page Data is invalid", nil)}];
                *stop = YES;
                return;
            }
            
            [pages addObject:page];
        }];
        
        
        if (error)
        {
//            NSLog(@"An error occurred while parsing one of the pages - can't proceed");
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
                error = [NSError errorWithDomain:kETA_CatalogReaderFetchedDataSource_ErrorDomain code:ETA_CatalogReaderFetchedDataSource_ErrorInvalidResponseData userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Hotspot Data is invalid", nil)}];
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
//            NSLog(@"An error occurred while parsing one of the hotspots - can't proceed");
            completion(nil, error);
            return;
        }
        
        
        
        NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
        NSLog(@"Both Fetches Completed (%.4f secs) - %tu pages", duration, pages.count);
        
        completion(pages, error);
    };
    
    
    
    
    dispatch_queue_t fetchCompletionQ = dispatch_get_global_queue(0, 0);
    
    [self.dataSource fetchPageImageDataForCatalogID:catalogID completion:^(NSArray *pageImageData, NSError *error) {
        dispatch_async(fetchCompletionQ, ^{
            fetchedPageImageData = pageImageData;
            pageImageDataFetchError = error;
            
            hasFetchedPages = YES;
            maybeHandleCompletion();
        });
    }];
    
    [self.dataSource fetchHotspotDataForCatalogID:catalogID completion:^(NSArray *hotspotData, NSError *error) {
        dispatch_async(fetchCompletionQ, ^{
            fetchedHotspotData = hotspotData;
            hotspotDataFetchError = error;
            
            hasFetchedHotspots = YES;
            maybeHandleCompletion();
        });
    }];
}



@end
