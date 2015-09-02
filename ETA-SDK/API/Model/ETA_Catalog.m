//
//  ETA_Catalog.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_Catalog.h"
#import "ETA_API.h"

@implementation ETA_Catalog

+ (NSString*) APIEndpoint { return ETA_API.catalogs; }


#pragma mark - JSON transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [super.JSONKeyPathsByPropertyKey
            mtl_dictionaryByAddingEntriesFromDictionary:@{
            @"backgroundColor": @"background",
            @"runFromDate": @"run_from",
            @"runTillDate": @"run_till",
            @"pageCount": @"page_count",
            @"offerCount": @"offer_count",
            
            @"dealerID": @"dealer_id",
            @"dealerURL": @"dealer_url",
            @"storeID": @"store_id",
            @"storeURL": @"store_url",
            
            @"imageURLBySize": @"images",
            @"pageImageURLsBySize": @"pages",
            
            @"store": NSNull.null,
            
            }];
}

+ (NSValueTransformer *) runFromDateJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}
+ (NSValueTransformer *) runTillDateJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_APIDate_ValueTransformerName];
}

+ (NSValueTransformer *)backgroundColorJSONTransformer {
    return [NSValueTransformer valueTransformerForName:ETA_HexColor_ValueTransformerName];
}

+ (NSValueTransformer *)dimensionsJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock: ^NSValue*(NSDictionary* dimDict)
            {
                CGSize size = CGSizeZero;
                
                if ([dimDict isKindOfClass:NSDictionary.class])
                {
                    NSNumber* width = dimDict[@"width"];
                    NSNumber* height = dimDict[@"height"];
                    
                    size.width = ([width isEqual:NSNull.null]) ? 0 : width.floatValue;
                    size.height = ([height isEqual:NSNull.null]) ? 0 : height.floatValue;
                }
                
                return [NSValue valueWithCGSize:size];
            } reverseBlock:^NSDictionary*(NSValue* sizeVal)
            {
                CGSize size = [sizeVal isKindOfClass:NSValue.class] ? [sizeVal CGSizeValue] : CGSizeZero;
                
                return @{ @"width": @(size.width),
                          @"height": @(size.height),
                          };
            }];
}

+ (NSValueTransformer *)dealerURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}
+ (NSValueTransformer *)storeURLJSONTransformer
{
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];    
}

+ (NSValueTransformer *)brandingJSONTransformer
{
    return [NSValueTransformer mtl_JSONDictionaryTransformerWithModelClass:ETA_Branding.class];
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

+ (NSValueTransformer *)pageImageURLsBySizeJSONTransformer
{
    NSValueTransformer* urlTransformer = [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
    
    return [MTLValueTransformer reversibleTransformerWithForwardBlock: ^NSDictionary*(NSDictionary* strsBySize)
            {
                NSMutableDictionary* urlsBySize = [NSMutableDictionary dictionaryWithCapacity:strsBySize.count];
                for (NSString* sizeKey in strsBySize.allKeys)
                {
                    NSArray* strs = strsBySize[sizeKey];
                    if (![strs isKindOfClass:NSArray.class])
                        strs = @[strs];
                    NSMutableArray* urls = [NSMutableArray arrayWithCapacity:strs.count];
                    for (NSString* str in strs)
                    {
                        NSURL* url = [urlTransformer transformedValue:str];
                        if (url)
                            [urls addObject:url];
                    }
                    
                    [urlsBySize setValue:urls forKey:sizeKey];
                }
                return urlsBySize;
            } reverseBlock:^NSDictionary*(NSDictionary* urlsBySize)
            {
                NSMutableDictionary* strsBySize = [NSMutableDictionary dictionaryWithCapacity:urlsBySize.count];
                for (NSString* sizeKey in urlsBySize.allKeys)
                {
                    NSArray* urls = urlsBySize[sizeKey];
                    if (![urls isKindOfClass:NSArray.class])
                        urls = @[urls];
                    NSMutableArray* strs = [NSMutableArray arrayWithCapacity:urls.count];
                    for (NSURL* url in urls)
                    {
                        NSString* str = [urlTransformer reverseTransformedValue:url];
                        if (str)
                            [strs addObject:str];
                    }
                    
                    [strsBySize setValue:strs forKey:sizeKey];
                }
                return strsBySize;
            }];
}




- (NSString*) sizeKeyForSize:(ETA_Catalog_ImageSize)size
{
    switch (size)
    {
        case ETA_Catalog_ImageSize_Thumb:
            return @"thumb";
            break;
            
        case ETA_Catalog_ImageSize_View:
            return @"view";
            break;
            
        case ETA_Catalog_ImageSize_Zoom:
            return @"zoom";
            break;
        default:
            break;
    }
    return nil;
}
- (NSURL*) imageURLForSize:(ETA_Catalog_ImageSize)imageSize
{
    NSString* sizeKey = [self sizeKeyForSize:imageSize];
    if (!sizeKey)
        return nil;
    return self.imageURLBySize[sizeKey];
}
- (NSArray*) pageImageURLsForSize:(ETA_Catalog_ImageSize)pageSize
{
    NSString* sizeKey = [self sizeKeyForSize:pageSize];
    if (!sizeKey)
        return nil;
    return self.pageImageURLsBySize[sizeKey];
}
@end
