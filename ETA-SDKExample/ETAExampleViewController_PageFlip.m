//
//  ETAExampleViewController_PageFlip.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETAExampleViewController_PageFlip.h"
#import "ETAAppDelegate.h"

#import "ETA_PageFlip.h"
#import "ETA.h"
#import "ETA-APIKeyAndSecret.h"

@interface ETAExampleViewController_PageFlip ()<ETAPageFlipDelegate>
@property (nonatomic, readwrite, strong) ETA_PageFlip* pageFlip;
@end

@implementation ETAExampleViewController_PageFlip

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
    
    
    UIButton* toggleButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [toggleButton addTarget:self action:@selector(toggleCatalog:) forControlEvents:UIControlEventTouchUpInside];
    toggleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [toggleButton setTitle:@"Toggle Catalog" forState:UIControlStateNormal];
    [toggleButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [toggleButton sizeToFit];
    toggleButton.frame = CGRectMake(CGRectGetMidX(self.view.bounds) - (toggleButton.frame.size.width/2),
                                    CGRectGetMaxY(self.view.bounds) - (toggleButton.frame.size.height + 10),
                                    toggleButton.frame.size.width, toggleButton.frame.size.height);
    
    toggleButton.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:toggleButton];
}


- (void) viewDidAppear:(BOOL)animated
{
}

- (IBAction)toggleCatalog:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5
                         animations:^{
                             self.pageFlip.alpha = 0.0;
                         } completion:^(BOOL finished) {
                             [self.pageFlip loadCatalog:([self.pageFlip.catalogID isEqualToString:@"bdea9Ig"]) ? @"d05d8Ig" : @"bdea9Ig"];
                         }];
    });
}

#pragma mark - PageFlip Delegate methods

// called when something is appears
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip readyEvent:(NSDictionary*)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:1
                         animations:^{
                             pageFlip.alpha = 1.0;
                         }];
    });
}
- (void)etaPageFlip:(ETA_PageFlip *)pageFlip didFailLoadWithError:(NSError *)error
{
    NSLog(@"Did Fail Load: %@ %@", pageFlip, error);
}

- (void)etaPageFlip:(ETA_PageFlip*)pageFlip catalogViewHotspotEvent:(NSDictionary*)data
{
    NSLog(@"Clicked Hotspot '%@'", data[@"heading"]);
}

// triggered for any event that you don't have a delegate method for
- (void)etaPageFlip:(ETA_PageFlip *)pageFlip triggeredEventWithClass:(NSString *)eventClass type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary
{
//    NSLog(@"triggeredEvent: '%@' '%@' %@", eventClass, type, dataDictionary);
}

- (void) etaPageFlip:(ETA_PageFlip *)pageFlip catalogViewPageChangeEvent:(NSDictionary *)data
{
    NSLog(@"Changed to %d / %d (%.2f%%)", pageFlip.currentPage, pageFlip.pageCount, pageFlip.pageProgress*100);
}
@end
