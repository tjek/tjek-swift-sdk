//
//  CatalogReaderViewController.m
//  ETA-SDK Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "CatalogReaderViewController.h"

#import <ETA-SDK/ETA_Catalog.h>
#import <ETA-SDK/ETA_CatalogReaderView.h>


@interface CatalogReaderViewController () <ETA_CatalogReaderViewDelegate>

@property (nonatomic, copy) NSString* catalogID;
@property (nonatomic, strong) UIColor* brandColor;
@property (nonatomic, strong) UIColor* alternateColor;
@end

@implementation CatalogReaderViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // In this example version the CatalogReaderView is created in the .storyboard
    // Doing so will use the default SDK singleton as the datasource.
    // If you want to use a different SDK instance there are alternative
    //   constructor methods you can use
    self.catalogReaderView.delegate = self;
    self.catalogReaderView.catalogID = self.catalogID;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // whenever the view appears, make sure that we are updated to show the catalog that was specified
    [self updateViewForFetchingState];
    
    // style the viewController based on the catalog's brand color
    [self updateViewForBrandColor];
    
    [self.catalogReaderView setSinglePageMode:[self _shouldBeSinglePageMode]
                                     animated:YES];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // You must call 'startReading' when the view appears - this triggers fetching of the data if needed
    [self.catalogReaderView startReading];
    
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // You must call 'stopReading' when the view disappears - this collects any pending page view information
    [self.catalogReaderView stopReading];
}


- (void) dealloc
{
    // destroy the reader when the view controller is deallocated
    _catalogReaderView = nil;
}



#pragma mark Layout
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    [self.catalogReaderView setSinglePageMode:[self _shouldBeSinglePageMode]
                                     animated:YES];
}


- (BOOL) _shouldBeSinglePageMode
{
    BOOL screenIsLandscape = self.interfaceOrientation == UIDeviceOrientationLandscapeRight || self.interfaceOrientation == UIDeviceOrientationLandscapeLeft;
    return !screenIsLandscape;
}


- (void) setCatalogID:(NSString*)catalogID title:(NSString*)catalogTitle brandColor:(UIColor*)brandColor
{
    NSParameterAssert(catalogID);
    
    self.catalogID = catalogID;
    
    // Setting the catalogID will reset the fetch jobs for the reader view. You should really only set it once.
    self.catalogReaderView.catalogID = catalogID;

    
    self.brandColor = brandColor;
    
    
    [self updateViewForBrandColor];
    
    
    self.title = catalogTitle;
}

- (void) updateViewForBrandColor
{
    CGFloat whiteComponent = 1.0;
    [self.brandColor getWhite:&whiteComponent alpha:NULL];
    if (whiteComponent > 0.5)
        self.alternateColor = [UIColor blackColor];
    else
        self.alternateColor = [UIColor whiteColor];
    
    
    // if the brand color is (almost) white, make it grey (so we can see it)
    UIColor* brandTextColor = (whiteComponent > 0.8) ? [UIColor grayColor] : self.brandColor;
    
    
    
    self.navigationController.navigationBar.tintColor = brandTextColor;
    self.view.backgroundColor = self.brandColor;
    
    self.activitySpinner.color = self.alternateColor;
}


- (void) updateViewForFetchingState
{
    if (self.catalogReaderView.isFetchingData || !self.catalogReaderView.pageObjects)
    {
        self.activitySpinner.alpha = 1.0;
        self.catalogReaderView.alpha = 0.0;
    }
    else
    {
        self.activitySpinner.alpha = 0.0;
        self.catalogReaderView.alpha = 1.0;
    }
}

- (IBAction)showHotspotsSwitched:(UISwitch*)switchView
{
    BOOL showHotspots = switchView.isOn;
    
    [self.catalogReaderView setShowHotspots:showHotspots animated:YES];
}







#pragma mark - Catalog Reader Delegate methods

- (void) catalogReaderViewDidStartFetchingData:(ETA_CatalogReaderView *)catalogReaderView
{
    [UIView animateWithDuration:0.4 animations:^{
        [self updateViewForFetchingState];
    }];
}


- (void) catalogReaderViewDidFinishFetchingData:(ETA_CatalogReaderView *)catalogReaderView error:(NSError*)error
{
    if (error)
    {
        DDLogError(@"Error Fetching Catalog Data: %@", error);
    }
    
    //TODO: if error show a message (unless it's the 'outdated' error)
    [UIView animateWithDuration:0.4 animations:^{
        [self updateViewForFetchingState];
    }];
}



- (void) catalogReaderView:(ETA_CatalogReaderView *)catalogReaderView didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspots:(NSArray*)hotspots
{
    DDLogInfo(@"tap hotspots: %@", [hotspots valueForKeyPath:@"offer.heading"]);
    
}
- (void) catalogReaderView:(ETA_CatalogReaderView *)catalogReaderView didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspots:(NSArray*)hotspots
{
    DDLogInfo(@"long press hotspots: %@", [hotspots valueForKeyPath:@"offer.heading"]);
}

- (UIColor*) versoPagedView:(ETA_VersoPagedView *)versoPagedView pageNumberLabelColorForPageIndex:(NSUInteger)pageIndex
{
    return self.alternateColor;
}


- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView beganScrollingFrom:(NSRange)currentPageIndexRange
{
    NSLog(@"began scrolling %@", NSStringFromRange(currentPageIndexRange));
}

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView beganScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    NSLog(@"began scrolling into %@ -> %@", NSStringFromRange(previousPageIndexRange), NSStringFromRange(newPageIndexRange));
}
- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView finishedScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    NSString* pageNumberString = [NSString stringWithFormat:@"%@", @(newPageIndexRange.location + 1)];
    if (versoPagedView.visiblePageIndexRange.length > 1)
        pageNumberString = [pageNumberString stringByAppendingFormat:@"-%@", @(newPageIndexRange.location + newPageIndexRange.length)];
    
    NSLog(@"Page changed: page %@/%@ (%.1f%%)", pageNumberString, @(versoPagedView.numberOfPages), versoPagedView.pageProgress*100.0);
}


@end
