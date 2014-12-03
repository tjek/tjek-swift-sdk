//
//  ETA_Store.m
//  Pods
//
//  Created by Laurie Hufford on 8/12/13.
//
//

#import "ETA_Store.h"
#import "ETA_API.h"

@implementation ETA_Store

+ (NSString*) APIEndpoint { return ETA_API.stores; }


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey
            mtl_dictionaryByAddingEntriesFromDictionary:@{
            @"zipCode": @"zip_code",
            
            @"dealerURL": @"dealer_url",
            @"dealerID": @"dealer_id",            
            }];
}


+ (NSValueTransformer *)dealerURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)brandingJSONTransformer
{
    return [NSValueTransformer mtl_JSONDictionaryTransformerWithModelClass:ETA_Branding.class];
}


- (CLLocationDistance) distanceFromLocation:(CLLocation*)location
{
    CLLocation* storeLocation = [[CLLocation alloc] initWithLatitude:self.latitude longitude:self.longitude];
    
    return [storeLocation distanceFromLocation:location];
}
@end
