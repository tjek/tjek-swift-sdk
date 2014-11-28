//
//  CatalogReaderDummyFetchedDataSource.m
//  NativeCatalogReader
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "CatalogReaderDummyFetchedDataSource.h"

@implementation CatalogReaderDummyFetchedDataSource

- (instancetype) initWithDelay:(NSTimeInterval)delay
{
    if (self = [super init])
    {
        _delay = delay;
    }
    return self;
}

- (void) fetchPageImageDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* pageImageData, NSError* error))completion
{
    NSParameterAssert(completion);
    
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.delay * NSEC_PER_SEC)), queue, ^{
        NSArray *json = nil;
        NSError* error = nil;
        
        NSString *filePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"pages-%@", catalogID] ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        if (data)
        {
            json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        }
        else
        {
            error = [NSError errorWithDomain:kETA_CatalogReaderFetchedDataSource_ErrorDomain code:ETA_CatalogReaderFetchedDataSource_ErrorInvalidResponseData userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No Page Image Data for Catalog ID", nil)}];
        }
        
        completion(json, error);
    });
}


- (void) fetchHotspotDataForCatalogID:(NSString*)catalogID completion:(void (^)(NSArray* hotspotData, NSError* error))completion
{
    NSParameterAssert(completion);
    
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.delay * NSEC_PER_SEC)), queue, ^{
        NSArray *json = nil;
        NSError* error = nil;
        
        NSString *filePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"hotspots-%@", catalogID] ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        if (data)
        {
            json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        }
        else
        {
            error = [NSError errorWithDomain:kETA_CatalogReaderFetchedDataSource_ErrorDomain code:ETA_CatalogReaderFetchedDataSource_ErrorInvalidResponseData userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No Hotspot Data for Catalog ID", nil)}];
        }
        
        completion(json, error);
    });
}

@end
