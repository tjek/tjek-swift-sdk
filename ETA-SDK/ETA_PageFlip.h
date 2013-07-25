//
//  ETA_PageFlip.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static NSString * const kETA_PageFlipBaseURLString = @"https://etilbudsavis.dk/";

@class ETA_PageFlip, ETA, ETA_Session;
@protocol ETAPageFlipDelegate <NSObject>

@optional

- (void)etaPageFlip:(ETA_PageFlip *)pageFlip didFailLoadWithError:(NSError *)error;

// all events trigger this method, unless you implement the optional event methods below
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip triggeredEventWithClass:(NSString *)eventClass type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary;

- (void)etaPageFlip:(ETA_PageFlip*)pageFlip readyEvent:(NSDictionary*)data;
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip sessionChangeEvent:(ETA_Session*)session;
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip geolocationChangeEvent:(NSDictionary*)data;
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip catalogViewPageChangeEvent:(NSDictionary*)data;
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip catalogViewHotspotEvent:(NSDictionary*)data;
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip catalogViewSingleTapEvent:(NSDictionary*)data;
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip catalogViewDoubleTapEvent:(NSDictionary*)data;
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip catalogViewDragStartEvent:(NSDictionary*)data;

@end


@interface ETA_PageFlip : UIView

// implement the delegate methods to get events from the page flip
@property (nonatomic, readwrite, assign) id<ETAPageFlipDelegate> delegate;


// If you init with no ETA object (or send nil) it will use the [ETA SDK] singleton.
// if the ETA object doesnt have an API key or secret (eg. you havn't initialized the singleton) this will return nil
- (id) init;
- (id) initWithETA:(ETA*)eta;
- (id) initWithETA:(ETA*)eta baseURL:(NSURL*)baseURL;


// try to show the catalog with the specified ID
// passing nil will close the catalog
// if currently in the process of loading a catalog, this will be a no-op
- (void) loadCatalog:(NSString *)catalogID;
- (void) loadCatalog:(NSString *)catalogID page:(NSUInteger)pageNumber;
- (void) loadCatalog:(NSString *)catalogID parameters:(NSDictionary*)parameters;

// remove the active catalog, and sets catalogID to nil
- (void) closeCatalog;

// the id of the catalog currently being shown.
// if loading a catalog fails, will be set to nil
@property (nonatomic, readonly, strong) NSString* catalogID;


// toggle the display of the thumbnail picker
- (void) toggleCatalogThumbnails;


@property (nonatomic, readonly, assign) NSUInteger currentPage;
@property (nonatomic, readonly, assign) NSUInteger pageCount;
@property (nonatomic, readonly, assign) CGFloat pageProgress;


// print out all requests and events. Defaults to NO.
@property (nonatomic, readwrite, assign) BOOL verbose;

@end
