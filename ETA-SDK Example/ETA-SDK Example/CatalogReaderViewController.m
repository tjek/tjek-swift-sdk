//
//  CatalogReaderViewController.m
//  ETA-SDK Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "CatalogReaderViewController.h"

#import "ETA_Catalog.h"

#import "ETA_CatalogReaderView.h"


@interface CatalogReaderViewController () <ETA_CatalogReaderViewDelegate>

@property (nonatomic, copy) NSString* catalogID;

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
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.catalogReaderView startReading];
    
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.catalogReaderView stopReading];
}


- (void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Show two images if the view is going landscape
    BOOL isLandscape = self.view.bounds.size.width > self.view.bounds.size.height;
    [self.catalogReaderView setSinglePageMode:!isLandscape];
}




- (void) dealloc
{
    self.catalogReaderView.delegate = nil;
}



- (void) setCatalogID:(NSString*)catalogID title:(NSString*)catalogTitle brandColor:(UIColor*)brandColor
{
    NSParameterAssert(catalogID);
    
    self.catalogID = catalogID;
    
    // Setting the catalogID will reset the fetch jobs for the reader view. You should really only set it once.
    self.catalogReaderView.catalogID = catalogID;

    
    
    // if the brand color is white, make it grey (so we can see it)
    UIColor* brandTextColor = ([brandColor isEqual:[UIColor colorWithRed:1 green:1 blue:1 alpha:1]]) ? [UIColor grayColor] : brandColor;
    
    self.navigationController.navigationBar.tintColor = brandTextColor;
    self.view.backgroundColor = brandColor;
    
    
    self.title = catalogTitle;
    
}



- (void) updateViewForFetchingState
{
    if (self.catalogReaderView.isFetchingData)
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


@end
