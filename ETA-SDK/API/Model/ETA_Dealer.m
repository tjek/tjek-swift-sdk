//
//  ETA_Dealer.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 04/07/14.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ETA_Dealer.h"
#import "ETA_API.h"

#import "NSValueTransformer+ETAPredefinedValueTransformers.h"

@implementation ETA_Dealer

+ (NSString*) APIEndpoint { return ETA_API.dealers; }


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"name": @"name",
              @"websiteURL": @"website",
              @"color": @"color",
              @"logoURL": @"logo",
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
+ (NSValueTransformer *) pageflipLogoURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}
+ (NSValueTransformer *) pageflipColorJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_HexColor_ValueTransformerName];
}

@end
