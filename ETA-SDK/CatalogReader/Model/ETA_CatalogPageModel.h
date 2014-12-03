//
//  ETA_CatalogPageModel.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 12/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ETA_CatalogHotspotModel.h"


@interface ETA_CatalogPageModel : NSObject

+ (instancetype) catalogPageWithPageIndex:(NSUInteger)pageIndex imageURLsBySize:(NSDictionary*)imageURLsBySize;


// index of page
- (NSUInteger) pageIndex;


// Hotspots
- (void) addHotspot:(ETA_CatalogHotspotModel*)hotspot;
- (NSArray*) allHotspots;


// ImageURL
- (NSURL*) imageURLForSizeName:(NSString*)sizeName;

@end
