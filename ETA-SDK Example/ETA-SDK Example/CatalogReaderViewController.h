//
//  CatalogReaderViewController.h
//  ETA-SDK Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ETA_CatalogReaderView;

@interface CatalogReaderViewController : UIViewController

- (void) setCatalogID:(NSString*)catalogID title:(NSString*)catalogTitle brandColor:(UIColor*)brandColor;

@property (weak, nonatomic) IBOutlet ETA_CatalogReaderView *catalogReaderView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activitySpinner;

- (IBAction)showHotspotsSwitched:(id)sender;

@end
