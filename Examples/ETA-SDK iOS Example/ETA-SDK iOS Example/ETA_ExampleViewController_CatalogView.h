//
//  ETA_ExampleViewController_CatalogView.h
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <UIKit/UIKit.h>

// This example shows how to present an interactive ETA_CatalogView
// It places a resizing ETA_CatalogView (a UIView subclass) on the screen and
//  loads the specified catalog object into it.
// It also handles the delegate messages the ETA_CatalogView sends

@class ETA_Catalog;
@interface ETA_ExampleViewController_CatalogView : UIViewController

@property (nonatomic, readwrite, strong) ETA_Catalog* catalog;

@end
