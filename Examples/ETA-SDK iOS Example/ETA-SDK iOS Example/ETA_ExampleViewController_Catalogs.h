//
//  ETA_ExampleViewController_Catalogs.h
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <UIKit/UIKit.h>

// This is a simple example that will populate a UITableView
// An API request will be sent to the SDK to get a list of ETA_Catalog objects.
// The objects will be relevant to the location that was passed in the AppDelegate.

@interface ETA_ExampleViewController_Catalogs : UIViewController

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activitySpinner;

@end
