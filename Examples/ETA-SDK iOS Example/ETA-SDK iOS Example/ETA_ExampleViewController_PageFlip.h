//
//  ETA_ExampleViewController_PageFlip.h
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/24/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ETA_Catalog;
@interface ETA_ExampleViewController_PageFlip : UIViewController

@property (nonatomic, readwrite, strong) ETA_Catalog* catalog;

@end