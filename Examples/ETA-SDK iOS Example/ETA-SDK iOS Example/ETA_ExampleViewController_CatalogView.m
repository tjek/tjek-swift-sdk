//
//  ETA_ExampleViewController_CatalogView.m
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ExampleViewController_CatalogView.h"

#import "ETA_CatalogView.h"
#import "ETA.h"
#import "ETA_Catalog.h"

@interface ETA_ExampleViewController_CatalogView ()<ETACatalogViewDelegate>
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activitySpinner;
@property (nonatomic, readwrite, strong) ETA_CatalogView* catalogView;
@property (nonatomic, readwrite, assign) BOOL isReady;
@end

@implementation ETA_ExampleViewController_CatalogView

- (void) setCatalog:(ETA_Catalog *)catalog
{
    NSString* catalogID = catalog.uuid;
    if (catalogID==_catalog.uuid || [catalogID isEqualToString:_catalog.uuid])
        return;
    
    _catalog = catalog;
    
    [self updateViewForCatalog];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.catalogView = [[ETA_CatalogView alloc] initWithETA:ETA.SDK];
    self.catalogView.delegate = self;
//    self.catalogView.verbose = YES;
    
    self.catalogView.frame = self.view.bounds;
    self.catalogView.alpha = 0;
    self.catalogView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.catalogView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [self updateViewForCatalog];
}

- (void) updateViewForCatalog
{
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
    
    self.isReady = NO;
    [self.catalogView loadCatalog:self.catalog.uuid];
}

#pragma mark - CatalogView Delegate methods

// called when something is ready to appear
- (void)etaCatalogView:(ETA_CatalogView*)catalogView readyEvent:(NSDictionary*)data
{
    
}
- (void)etaCatalogView:(ETA_CatalogView *)catalogView didFailLoadWithError:(NSError *)error
{
    [self.activitySpinner stopAnimating];
}

- (void)etaCatalogView:(ETA_CatalogView*)catalogView catalogViewHotspotEvent:(NSDictionary*)data
{
    NSLog(@"Clicked Hotspot '%@'", data[@"heading"]);
    UIAlertView* alert = [[UIAlertView alloc] init];
    alert.title = data[@"heading"];
    [alert addButtonWithTitle:NSLocalizedString(@"OK",@"OK")];
    [alert show];
}

// triggered for any event that you don't have a delegate method for
- (void)etaCatalogView:(ETA_CatalogView *)catalogView triggeredEventWithClass:(NSString *)eventClass type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary
{
//    NSLog(@"triggeredEvent: '%@' '%@' %@", eventClass, type, dataDictionary);
}

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
    NSLog(@"Changed to %d / %d (%.2f%%)", catalogView.currentPage, catalogView.pageCount, catalogView.pageProgress*100);
}
@end
