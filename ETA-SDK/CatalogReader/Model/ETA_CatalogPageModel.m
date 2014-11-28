//
//  ETA_CatalogPageModel.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 12/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_CatalogPageModel.h"

@interface ETA_CatalogPageModel ()

@property (nonatomic, assign) NSUInteger pageIndex;
@property (nonatomic, strong) NSDictionary* imageURLsBySize;
@property (nonatomic, strong) NSMutableArray* hotspots;

@end

@implementation ETA_CatalogPageModel

+ (instancetype) catalogPageWithPageIndex:(NSUInteger)pageIndex imageURLsBySize:(NSDictionary*)imageURLsBySize
{
    ETA_CatalogPageModel* page = [ETA_CatalogPageModel new];
    page.pageIndex = pageIndex;
    page.imageURLsBySize = imageURLsBySize;
    
    return page;
}


- (NSMutableArray*) hotspots
{
    if (!_hotspots)
    {
        _hotspots = [NSMutableArray new];
    }
    return _hotspots;
}



// add a hotspot to this page
- (void) addHotspot:(ETA_CatalogHotspotModel*)hotspot
{
    if (!hotspot)
        return;
    
    [self.hotspots addObject:hotspot];
}


#pragma mark - Protocol implementation

- (NSURL*) imageURLForSizeName:(NSString*)sizeName
{
    if (!sizeName)
        return nil;
    return self.imageURLsBySize[sizeName];
}

- (NSArray*) allHotspots
{
    return [NSArray arrayWithArray:self.hotspots];
}


@end
