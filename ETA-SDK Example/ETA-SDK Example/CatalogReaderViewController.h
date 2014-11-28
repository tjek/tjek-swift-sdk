//
//  CatalogReaderViewController.h
//  ETA-SDK Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <UIKit/UIKit.h>


@class ETA_Catalog;
@interface CatalogReaderViewController : UIViewController

- (void) setCatalog:(ETA_Catalog*)catalog;
- (void) setCatalogID:(NSString*)catalogID title:(NSString*)catalogTitle brandColor:(UIColor*)brandColor;


@property (weak, nonatomic) IBOutlet UIView *catalogContainerView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activitySpinner;

@end
