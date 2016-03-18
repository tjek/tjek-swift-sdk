//
//  ETA_Offer.m
//  Pods
//
//  Created by Laurie Hufford on 8/14/13.
//
//

#import "ETA_Offer.h"
#import "ETA_API.h"

@implementation ETA_Offer

+ (NSString*) APIEndpoint { return ETA_API.offers; }

#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey
            mtl_dictionaryByAddingEntriesFromDictionary:@{
                                                          @"details": @"description",
                                                          @"catalogPage": @"catalog_page",
                                                          
                                                          @"price": @"pricing.price",
                                                          @"preprice": @"pricing.preprice",
                                                          @"currency": @"pricing.currency",
                                                          
                                                          @"quantityUnit": @"quantity.unit",
                                                          @"quantitySize": @"quantity.size",
                                                          @"quantityPieces": @"quantity.pieces",
                                                          
                                                          @"imageURLBySize": @"images",
                                                          
                                                          @"runFromDate": @"run_from",
                                                          @"runTillDate": @"run_till",
                                                          @"publishDate": @"publish",
                                                          
                                                          @"dealerURL": @"dealer_url",
                                                          @"storeURL": @"store_url",
                                                          @"catalogURL": @"catalog_url",
                                                          
                                                          @"dealerID": @"dealer_id",
                                                          @"storeID": @"store_id",
                                                          @"catalogID": @"catalog_id",                                                          
                                                          
                                                          @"webshopURL": @"links.webshop",
                                                          
                                                          @"store": NSNull.null,
                                                          @"branding": @"branding",
                                                          
                                                          }];
}

+ (NSValueTransformer *) runFromDateJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}
+ (NSValueTransformer *) runTillDateJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}
+ (NSValueTransformer *) publishDateJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}

+ (NSValueTransformer *)brandingJSONTransformer
{
    return [NSValueTransformer mtl_JSONDictionaryTransformerWithModelClass:ETA_Branding.class];
}

+ (NSValueTransformer *)dealerURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}
+ (NSValueTransformer *)storeURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}
+ (NSValueTransformer *)catalogURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)webshopURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

+ (NSValueTransformer *)imageURLBySizeJSONTransformer
{
    NSValueTransformer* urlTransformer = [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
    
    return [MTLValueTransformer reversibleTransformerWithForwardBlock: ^NSDictionary*(NSDictionary* strsBySize)
            {
                NSMutableDictionary* urls = [NSMutableDictionary dictionaryWithCapacity:strsBySize.count];
                for (NSString* sizeKey in strsBySize.allKeys)
                {
                    NSString* str = strsBySize[sizeKey];
                    NSURL* url = [urlTransformer transformedValue:str];
                    [urls setValue:url forKey:sizeKey];
                }
                return urls;
            } reverseBlock:^NSDictionary*(NSDictionary* urlsBySize)
            {
                NSMutableDictionary* strs = [NSMutableDictionary dictionaryWithCapacity:urlsBySize.count];
                for (NSString* sizeKey in urlsBySize.allKeys)
                {
                    NSURL* url = urlsBySize[sizeKey];
                    NSString* str = [urlTransformer reverseTransformedValue:url];
                    [strs setValue:str forKey:sizeKey];
                }
                return strs;
            }];
}

- (NSString*) sizeKeyForSize:(ETA_Offer_ImageSize)size
{
    switch (size)
    {
        case ETA_Offer_ImageSize_Thumb:
            return @"thumb";
            break;
            
        case ETA_Offer_ImageSize_View:
            return @"view";
            break;
            
        case ETA_Offer_ImageSize_Zoom:
            return @"zoom";
            break;
        default:
            break;
    }
    return nil;
}
- (NSURL*) imageURLForSize:(ETA_Offer_ImageSize)imageSize
{
    NSString* sizeKey = [self sizeKeyForSize:imageSize];
    if (!sizeKey)
        return nil;
    return self.imageURLBySize[sizeKey];
}

- (void) setWebshopURL:(NSURL *)webshopURL
{
    if (_webshopURL == webshopURL)
        return;
    
    _webshopURL = webshopURL;
    
    NSString* link = [self.class.webshopURLJSONTransformer reverseTransformedValue:webshopURL];
    
    NSMutableDictionary* mutoLinks = [self.links mutableCopy];
    mutoLinks[@"webshop"] = link;
    self.links = mutoLinks;
}
@end
