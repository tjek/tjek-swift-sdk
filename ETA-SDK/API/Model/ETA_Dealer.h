//
//  ETA_Dealer.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 04/07/14.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ETA_ModelObject.h"

/**
 *  A Dealer object
 *
 *  Although this may look a _lot_ like an ETA_Branding object (and it is a lot like a branding object), they are not the same thing.
 *  For one, this has an ERN.
 */
@interface ETA_Dealer : ETA_ModelObject

@property (nonatomic, readwrite, strong) NSString* name;
@property (nonatomic, readwrite, strong) NSURL* websiteURL;
@property (nonatomic, readwrite, strong) UIColor* color;
@property (nonatomic, readwrite, strong) NSURL* logoURL;
@property (nonatomic, readwrite, strong) NSURL* pageflipLogoURL;
@property (nonatomic, readwrite, strong) UIColor* pageflipColor;

@end
