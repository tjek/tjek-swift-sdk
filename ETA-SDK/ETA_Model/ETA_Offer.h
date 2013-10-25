//
//  ETA_Offer.h
//  Pods
//
//  Created by Laurie Hufford on 8/14/13.
//
//

#import "ETA_ModelObject.h"

#import "ETA_Store.h"

typedef enum {
    ETA_Offer_ImageSize_Thumb = 0,
    ETA_Offer_ImageSize_View = 1,
    ETA_Offer_ImageSize_Zoom = 2,
} ETA_Offer_ImageSize;

@interface ETA_Offer : ETA_ModelObject

@property (nonatomic, strong) NSString* heading;
@property (nonatomic, strong) NSString* details; // actually 'description'
@property (nonatomic, assign) NSInteger catalogPage;

@property (nonatomic, assign) CGFloat price;
@property (nonatomic, assign) CGFloat preprice;
@property (nonatomic, strong) NSString* currency;

@property (nonatomic, strong) NSDictionary* quantityUnit;
@property (nonatomic, strong) NSDictionary* quantitySize;
@property (nonatomic, strong) NSDictionary* quantityPieces;

@property (nonatomic, readwrite, strong) NSDictionary* imageURLBySize;

@property (nonatomic, readwrite, strong) NSDictionary* links;
@property (nonatomic, readwrite, strong) NSURL* webshopURL;

@property (nonatomic, readwrite, strong) NSDate* runFromDate;
@property (nonatomic, readwrite, strong) NSDate* runTillDate;
@property (nonatomic, readwrite, strong) NSDate* publishDate;

@property (nonatomic, readwrite, strong) NSURL* dealerURL;
@property (nonatomic, readwrite, strong) NSURL* storeURL;
@property (nonatomic, readwrite, strong) NSURL* catalogURL;

@property (nonatomic, readwrite, strong) NSString* dealerID;
@property (nonatomic, readwrite, strong) NSString* storeID;
@property (nonatomic, readwrite, strong) NSString* catalogID;

- (NSURL*) imageURLForSize:(ETA_Offer_ImageSize)imageSize;

/**
 *	You need to fetch/assign the Store property yourself using the storeID property - it will be nil until populated.
 */
@property (nonatomic, readwrite, strong) ETA_Store* store;

@end
