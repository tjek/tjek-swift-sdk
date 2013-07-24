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
    self.eta = ((ETAAppDelegate*)UIApplication.sharedApplication.delegate).eta;
    

    self.pageFlip = [[ETA_PageFlip alloc] init];
//    self.pageFlip.verbose = YES;
    self.pageFlip.frame = self.view.bounds;
    self.pageFlip.alpha = 0;
    self.pageFlip.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.pageFlip];
    
    self.pageFlip.etaDelegate = self;
    [self.pageFlip startLoadWithETA:self.eta];
    self.pageFlip.catalogID = @"d05d8Ig";
}

#pragma mark - PageFlip Delegate methods

// called when something is appears
- (void)etaPageFlip:(ETA_PageFlip*)pageFlip readyEvent:(NSDictionary*)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:2
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

@end
