//
//  ETA_WebView.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

static NSString * const kETA_WebViewBaseURLString = @"https://etilbudsavis.dk/";

@class ETA_WebView;
@protocol ETAWebViewDelegate <NSObject>

@optional

- (void)etaWebViewDidStartLoad:(ETA_WebView *)webView;
- (void)etaWebViewDidFinishLoad:(ETA_WebView *)webView;
- (void)etaWebView:(ETA_WebView *)webView didFailLoadWithError:(NSError *)error;

// all events trigger this method, unless you implement the optional event methods below
- (void)etaWebView:(ETA_WebView *)webView triggeredEventWithClass:(NSString *)eventClass type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary;
- (void)etaWebView:(ETA_WebView*)webview proxyReadyEvent:(NSDictionary*)data;
- (void)etaWebView:(ETA_WebView*)webview sessionChangeEvent:(NSDictionary*)data;
- (void)etaWebView:(ETA_WebView*)webview catalogViewPageChangeEvent:(NSDictionary*)data;
- (void)etaWebView:(ETA_WebView*)webview catalogViewOutOfBoundsEvent:(NSDictionary*)data;
- (void)etaWebView:(ETA_WebView*)webview catalogViewHotspotEvent:(NSDictionary*)data;
- (void)etaWebView:(ETA_WebView*)webview catalogViewSingleTapEvent:(NSDictionary*)data;
- (void)etaWebView:(ETA_WebView*)webview catalogViewDoubleTapEvent:(NSDictionary*)data;
- (void)etaWebView:(ETA_WebView*)webview catalogViewDragStartEvent:(NSDictionary*)data;

@end


@class ETA, ETA_Session;
@interface ETA_WebView : UIWebView

// you must not set the UIWebView delegate on ETA_WebView objects - it will assert
@property (nonatomic, readwrite, assign) id<ETAWebViewDelegate> etaDelegate;

@property (nonatomic, readonly, strong) NSString* uuid;


- (void) startLoadWithETA:(ETA*)eta;
- (void) startLoadWithETA:(ETA*)eta baseURL:(NSURL*)baseURL;

// show a catalog view. Optional parameters:
// - page: The desired page to start on (NSUInteger).
// - hotspots: Whether to enable or disable hotspots or not (BOOL).
// - hotspotOverlay: Whether to disable hotspot overlay or not (BOOL).
// - canClose: Whether the catalog view can close or not (BOOL).
// - headless: Whether the header should be disabled or not (BOOL, default=YES).
// - outOfBounds: Whether to show out of bounds dialog or not (BOOL, default=NO).
// - whiteLabel: Whether to disable branding or not (BOOL).
- (void) showCatalogView:(NSString*)catalogID parameters:(NSDictionary*)parameters;

- (void) closeCatalogView;
- (void) toggleCatalogViewThumbnails;
- (void) changeSession:(ETA_Session*)session;
- (void) changeLocation:(CLLocation*)location distance:(NSNumber*)distance fromSensor:(BOOL)fromSensor;


// print out all requests and events
@property (nonatomic, readwrite, assign) BOOL verbose;

@end
