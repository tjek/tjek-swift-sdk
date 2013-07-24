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

@class ETA_PageFlip, ETA_Session;
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


@class ETA;
@interface ETA_PageFlip : UIWebView

// you must not set the UIWebView delegate on ETA_PageFlip objects - it will assert
@property (nonatomic, readwrite, assign) id<ETAPageFlipDelegate> etaDelegate;

@property (nonatomic, readonly, strong) NSString* uuid;


- (void) startLoadWithETA:(ETA*)eta;
- (void) startLoadWithETA:(ETA*)eta baseURL:(NSURL*)baseURL;


// the id of the catalog currently being shown.
// setting this will try to show the catalog with default parameters
// setting to nil will close the catalog
@property (nonatomic, readwrite, strong) NSString* catalogID;

// show a catalog view. updates the catalogID property.
// Optional parameters:
// - page: The desired page to start on (NSUInteger, default=1).
// - hotspots: Whether to send events when a hotspot is pressed (BOOL, default=YES).
// - hotspotOverlay: Whether to show an overlay when hovering over a hotspot - doesnt make sense for iOS (BOOL, default=NO).
// - canClose: Whether the catalog view can close or not (BOOL, default=NO).
// - headless: Whether the header should be hidden or shown (BOOL, default=YES).
// - outOfBounds: Whether to show a dialog when past the last page (BOOL, default=NO).
// - whiteLabel: Whether to show ETA branding (BOOL, default=YES).
- (void) showCatalogView:(NSString*)catalogID parameters:(NSDictionary*)parameters;

// hide the catalogview and sets catalogID to nil
- (void) closeCatalogView;

// toggle the display of thumbnail picker
- (void) toggleCatalogViewThumbnails;

// these shouldn't be public?
- (void) changeSession:(ETA_Session*)session;
- (void) changeLocation:(CLLocation*)location distance:(NSNumber*)distance fromSensor:(BOOL)fromSensor;


// print out all requests and events
@property (nonatomic, readwrite, assign) BOOL verbose;

@end
