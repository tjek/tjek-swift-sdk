//
//  ETA_CatalogHotspotModel.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 12/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <Mantle/Mantle.h>

@interface ETA_CatalogHotspotModel : MTLModel <MTLJSONSerializing>

- (NSIndexSet*) activePageIndexes;
- (NSArray*) coordPointsForPageIndex:(NSUInteger)pageIndex;
- (CGRect) boundingRectForPageIndex:(NSUInteger)pageIndex;

@end


@class ETA_Offer;
@interface ETA_CatalogOfferHotspotModel : ETA_CatalogHotspotModel

@property (nonatomic, strong, readonly) ETA_Offer* offer;

@end