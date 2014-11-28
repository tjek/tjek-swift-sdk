//
//  NSValueTransformer+ETAPredefinedValueTransformers.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>

// convert @"FFFFFF" <-> UIColor
extern NSString * const ETA_HexColor_ValueTransformerName;

// convert NSString <-> NSDate, using ETA's API date formatter style
extern NSString * const ETA_APIDate_ValueTransformerName;


@interface NSValueTransformer (ETAPredefinedValueTransformers)

@end
