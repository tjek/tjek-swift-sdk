//
//  ETA_Branding.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

@import Mantle;
@import UIKit;

@interface ETA_Branding : MTLModel<MTLJSONSerializing>

@property (nonatomic, readwrite, strong) NSString* name;
@property (nonatomic, readwrite, strong) NSURL* websiteURL;
@property (nonatomic, readwrite, strong) UIColor* color;
@property (nonatomic, readwrite, strong) NSURL* logoURL;
@property (nonatomic, readwrite, strong) NSURL* pageflipLogoURL;
@property (nonatomic, readwrite, strong) UIColor* pageflipColor;
@property (nonatomic, readwrite, strong) NSString* brandDescription;
@end
