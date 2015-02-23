//
//  ETA_Branding.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_Branding.h"

#import "NSValueTransformer+ETAPredefinedValueTransformers.h"

//#import "NSDictionary+MTLManipulationAdditions.h"
//#import "NSValueTransformer+MTLPredefinedTransformerAdditions.h"

@implementation ETA_Branding

#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"name": @"name",
              @"urlName": @"url_name",
              @"websiteURL": @"website",
              
              @"color": @"color",
              @"logoURL": @"logo",
              @"logoBackgroundColor": @"logo_background",
              
              @"pageflipLogoURL": @"pageflip.logo",
              @"pageflipColor": @"pageflip.color",
              };
}

+ (NSValueTransformer *) websiteURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}
+ (NSValueTransformer *) colorJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_HexColor_ValueTransformerName];
}
+ (NSValueTransformer *) logoURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}
+ (NSValueTransformer *) logoBackgroundColorJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_HexColor_ValueTransformerName];
}
+ (NSValueTransformer *) pageflipLogoURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}
+ (NSValueTransformer *) pageflipColorJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_HexColor_ValueTransformerName];
}

@end
