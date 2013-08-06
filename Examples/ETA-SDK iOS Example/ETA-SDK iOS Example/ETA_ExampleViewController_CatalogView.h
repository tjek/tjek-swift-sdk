//
//  ETA_ExampleViewController_CatalogView.h
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ETA_Catalog;
@interface ETA_ExampleViewController_CatalogView : UIViewController

@property (nonatomic, readwrite, strong) ETA_Catalog* catalog;

@end
