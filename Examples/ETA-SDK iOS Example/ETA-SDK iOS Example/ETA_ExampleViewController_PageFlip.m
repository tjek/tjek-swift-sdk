//
//  ETA_ExampleViewController_PageFlip.m
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ExampleViewController_PageFlip.h"

#import "ETA_PageFlip.h"
#import "ETA.h"
#import "ETA_Catalog.h"

@interface ETA_ExampleViewController_PageFlip ()<ETAPageFlipDelegate>
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activitySpinner;
@property (nonatomic, readwrite, strong) ETA_PageFlip* pageFlip;
@property (nonatomic, readwrite, assign) BOOL isReady;
@end

@implementation ETA_ExampleViewController_PageFlip

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
    
    self.pageFlip = [[ETA_PageFlip alloc] initWithETA:ETA.SDK];
    self.pageFlip.delegate = self;
//    self.pageFlip.verbose = YES;
    
    self.pageFlip.frame = self.view.bounds;
    self.pageFlip.alpha = 0;
    self.pageFlip.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.pageFlip];
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
    [self.pageFlip loadCatalog:self.catalog.uuid];
}

#pragma mark - PageFlip Delegate methods

// called when something is ready to appear
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip readyEvent:(NSDictionary*)data
{
    
}
- (void)etaPageFlip:(ETA_PageFlip *)pageFlip didFailLoadWithError:(NSError *)error
{
    [self.activitySpinner stopAnimating];
}

- (void)etaPageFlip:(ETA_PageFlip*)pageFlip catalogViewHotspotEvent:(NSDictionary*)data
{
    NSLog(@"Clicked Hotspot '%@'", data[@"heading"]);
    UIAlertView* alert = [[UIAlertView alloc] init];
    alert.title = data[@"heading"];
    [alert addButtonWithTitle:NSLocalizedString(@"OK",@"OK")];
    [alert show];
}

// triggered for any event that you don't have a delegate method for
- (void)etaPageFlip:(ETA_PageFlip *)pageFlip triggeredEventWithClass:(NSString *)eventClass type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary
{
//    NSLog(@"triggeredEvent: '%@' '%@' %@", eventClass, type, dataDictionary);
}

- (void) etaPageFlip:(ETA_PageFlip *)pageFlip catalogViewPageChangeEvent:(NSDictionary *)data
{
    // although etaPageFlip:readyEvent: marks when the pageflip is ready, the catalog may not be fully drawn yet
    // the page change event is a better point for knowing when drawing is ready
    if (self.isReady == NO)
    {
        self.isReady = YES;
        [self.activitySpinner stopAnimating];
        [UIView animateWithDuration:1
                         animations:^{
                                pageFlip.alpha = 1.0;
                            }];
    }
    NSLog(@"Changed to %d / %d (%.2f%%)", pageFlip.currentPage, pageFlip.pageCount, pageFlip.pageProgress*100);
}
@end
