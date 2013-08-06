//
//  ETA_Catalog.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ModelObject.h"
#import "ETA_Branding.h"

typedef enum {
    ETA_Catalog_ImageSize_Thumb = 0,
    ETA_Catalog_ImageSize_View = 1,
    ETA_Catalog_ImageSize_Zoom = 2,
} ETA_Catalog_ImageSize;


@interface ETA_Catalog : ETA_ModelObject

@property (nonatomic, readwrite, strong) NSString* label;
@property (nonatomic, readwrite, strong) UIColor* backgroundColor;
@property (nonatomic, readwrite, strong) NSDate* runFromDate;
@property (nonatomic, readwrite, strong) NSDate* runTillDate;
@property (nonatomic, readwrite, assign) NSInteger pageCount;
@property (nonatomic, readwrite, assign) NSInteger offerCount;

@property (nonatomic, readwrite, strong) ETA_Branding* branding;

@property (nonatomic, readwrite, strong) NSString* dealerID;
@property (nonatomic, readwrite, strong) NSURL* dealerURL;
@property (nonatomic, readwrite, strong) NSString* storeID;
@property (nonatomic, readwrite, strong) NSURL* storeURL;

@property (nonatomic, readwrite, assign) CGSize dimensions;

@property (nonatomic, readwrite, strong) NSDictionary* imageURLBySize;
@property (nonatomic, readwrite, strong) NSDictionary* pageImageURLsBySize;



- (NSURL*) imageURLForSize:(ETA_Catalog_ImageSize)imageSize;
- (NSArray*) pageImageURLsForSize:(ETA_Catalog_ImageSize)pageSize;

@end
