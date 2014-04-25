//
//  ETA_ExampleViewController_CatalogView.m
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ExampleViewController_CatalogView.h"

#import "ETA.h"
#import "ETA_CatalogView.h"
#import "ETA_Catalog.h"

@interface ETA_ExampleViewController_CatalogView ()<ETACatalogViewDelegate>

// this is our instance of the CatalogView
// it is a UIView subclass that handles all the interaction with the magazine
@property (nonatomic, readwrite, strong) ETA_CatalogView* catalogView;

// a spinner that shows the catalogView is loading
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activitySpinner;

// is the catalogView in the process of loading?
@property (nonatomic, readwrite, assign) BOOL isReady;

@end

@implementation ETA_ExampleViewController_CatalogView

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight;
    
    // first you must initialize the CatalogView with the ETA object that is being used by your app
    self.catalogView = [[ETA_CatalogView alloc] initWithETA:ETA.SDK];
    
    // in order to handle messages from the view we must be the delegate (ETACatalogViewDelegate)
    self.catalogView.delegate = self;
    
    // you can get a lot of info if you turn on verbose mode
//    self.catalogView.verbose = YES;
    // place the catalogView on the screen, and make it resize automatically.
    self.catalogView.frame = self.view.bounds;
    self.catalogView.alpha = 0;
    self.catalogView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.catalogView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // whenever the view appears, make sure that we are updated to show the catalog that was specified
    [self updateViewForCatalog];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // when the view is
    self.catalogView.pauseCatalog = NO;
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    self.catalogView.pauseCatalog = YES;
}


// When you set the catalog object on this ViewController it will update the catalog view
// This may be called before viewDidLoad, so we can't be sure that updateViewForCatalog will actually update as expected
- (void) setCatalog:(ETA_Catalog *)catalog
{
    NSString* catalogID = catalog.uuid;
    if (catalogID==_catalog.uuid || [catalogID isEqualToString:_catalog.uuid])
        return;
    
    _catalog = catalog;
    
    [self updateViewForCatalog];
}

// Make sure we are showing the catalog correctly
- (void) updateViewForCatalog
{
    // update the title, color, and spinner, depending on if we have a catalog or not
    if (self.catalog)
    {
        [self.activitySpinner startAnimating];
        
        self.title = self.catalog.branding.name;
        
        UIColor* brandColor = (self.catalog.branding.pageflipColor) ?: self.catalog.branding.color;
        
        // if the brand color is white, make it grey (so we can see it)
        UIColor* brandTextColor = ([brandColor isEqual:[UIColor colorWithRed:1 green:1 blue:1 alpha:1]]) ? [UIColor grayColor] : brandColor;
        
        self.navigationController.navigationBar.tintColor = brandTextColor;
        self.view.backgroundColor = brandColor;
    }
    else
    {
        [self.activitySpinner stopAnimating];
        self.title = @"";
        
        self.navigationController.navigationBar.tintColor = nil;
        self.view.backgroundColor = [UIColor viewFlipsideBackgroundColor];
    }
    
    // we are starting to load the catalog
    self.isReady = NO;
    
    // tell the catalogView to start loading the ID of catalog we are looking at
    // if nil then it will remove the previous catalog
    [self.catalogView loadCatalog:self.catalog.uuid];
}


// The following Delegate methods are all optional
// They are sent from the CatalogView, so we know when things happen.
#pragma mark - CatalogView Delegate methods


// Called when something is ready to appear (it may not be drawn yet, however)
- (void)etaCatalogView:(ETA_CatalogView*)catalogView readyEvent:(NSDictionary*)data
{
}

// Something bad happened while we were loading the catalog
- (void)etaCatalogView:(ETA_CatalogView *)catalogView didFailLoadWithError:(NSError *)error
{
    [self.activitySpinner stopAnimating];
}

// Called when page changes in the catalog.
// We can use this to know when the catalog is being drawn (so we can fade the catalog in)
- (void) etaCatalogView:(ETA_CatalogView *)catalogView catalogViewPageChangeEvent:(NSDictionary *)data
{
    // although etaCatalogView:readyEvent: marks when the catalog is ready, the catalog may not be fully drawn yet
    // the page change event is a better point for knowing when drawing is ready
    if (self.isReady == NO)
    {
        self.isReady = YES;
        [self.activitySpinner stopAnimating];
        [UIView animateWithDuration:1
                         animations:^{
                             catalogView.alpha = 1.0;
                         }];
    }
    DDLogInfo(@"Changed to %d / %d (%.2f%%)", catalogView.currentPage, catalogView.pageCount, catalogView.pageProgress*100);
}

// The user touched one of the hotspots in the catalog
- (void)etaCatalogView:(ETA_CatalogView*)catalogView catalogViewHotspotEvent:(NSDictionary*)data
{
    DDLogInfo(@"Clicked Hotspot '%@'", data[@"heading"]);
    UIAlertView* alert = [[UIAlertView alloc] init];
    alert.title = data[@"heading"];
    [alert addButtonWithTitle:NSLocalizedString(@"OK",@"OK")];
    [alert show];
}

// This delegate method is the generic method, and will be called for all events that aren't handled by other delegate methods
- (void)etaCatalogView:(ETA_CatalogView *)catalogView triggeredEventWithClass:(NSString *)eventClass type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary
{
}
@end
