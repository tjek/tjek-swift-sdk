//
//  ETA_CatalogHotspotModel.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 12/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_CatalogHotspotModel.h"

@interface ETA_CatalogHotspotModel ()

@property (nonatomic, strong) NSDictionary* locationsByPageIndex;

@end

@implementation ETA_CatalogHotspotModel

+ (Class)classForParsingJSONDictionary:(NSDictionary *)JSONDictionary {
    if ([JSONDictionary[@"type"] isEqualToString:@"offer"] && JSONDictionary[@"offer"] != nil)
    {
        return ETA_CatalogOfferHotspotModel.class;
    }
    
    return nil;
}


+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"locationsByPageIndex": @"locations",
             };
}

+ (NSValueTransformer *)locationsByPageIndexJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSDictionary *jsonDict) {
        __block NSMutableDictionary* modelDict = [NSMutableDictionary dictionary];
        
        [jsonDict enumerateKeysAndObjectsUsingBlock:^(NSString* pageNumberKey, NSArray* jsonLocations, BOOL *stop) {
            
            // skip non-integerable pageNumbers
            if ([pageNumberKey respondsToSelector:@selector(integerValue)] == NO)
            {
                return;
            }
            
            NSInteger pageIndex = pageNumberKey.integerValue-1;
            // invalid index
            if (pageIndex < 0)
            {
                return;
            }
            
            __block NSMutableArray* modelLocations = [NSMutableArray arrayWithCapacity:jsonLocations.count];
            
            [jsonLocations enumerateObjectsUsingBlock:^(NSArray* jsonCoords, NSUInteger idx, BOOL *stop) {
                
                if (jsonCoords.count >= 2)
                {
                    CGPoint pointCoord = CGPointMake([(NSString*)jsonCoords[0] floatValue], [(NSString*)jsonCoords[1] floatValue]);
                    
                    [modelLocations addObject:[NSValue valueWithCGPoint:pointCoord]];
                }
            }];
            
            if (modelLocations.count)
                modelDict[@(pageIndex)] = modelLocations;
        }];
        return modelDict;
        
    } reverseBlock:^id(NSDictionary* modelDict) {
        __block NSMutableDictionary* jsonDict = [NSMutableDictionary dictionary];
        
        [modelDict enumerateKeysAndObjectsUsingBlock:^(NSNumber* pageIndexKey, NSArray* modelLocations, BOOL *stop) {
            
            // skip non-integerable pageNumbers
            if ([pageIndexKey respondsToSelector:@selector(integerValue)] == NO)
            {
                return;
            }
            
            NSInteger pageNumber = pageIndexKey.integerValue+1;
            
            NSMutableArray* jsonLocations = [NSMutableArray arrayWithCapacity:modelLocations.count];
            
            [modelLocations enumerateObjectsUsingBlock:^(NSValue* modelCoord, NSUInteger idx, BOOL *stop) {
                
                CGPoint pointCoord = [modelCoord CGPointValue];
                
                NSArray* jsonCoords = @[ [NSString stringWithFormat:@"%@", @(pointCoord.x)], [NSString stringWithFormat:@"%@", @(pointCoord.y)] ];
                
                [jsonLocations addObject:jsonCoords];
            }];
            
            if (jsonLocations.count)
                jsonDict[@(pageNumber)] = jsonLocations;
        }];
        return jsonDict;
    }];
}

- (NSIndexSet*) activePageIndexes
{
    NSMutableIndexSet* pageIndexes = [NSMutableIndexSet indexSet];
    for (NSNumber* pageIndex in self.locationsByPageIndex.allKeys)
    {
        [pageIndexes addIndex:pageIndex.integerValue];
    }
    return pageIndexes;
}

- (NSArray*) coordPointsForPageIndex:(NSUInteger)pageIndex
{
    return self.locationsByPageIndex[@(pageIndex)];
}

- (CGRect) boundingRectForPageIndex:(NSUInteger)pageIndex
{
    NSArray* coords = [self coordPointsForPageIndex:pageIndex];
    if (!coords.count)
    {
        return CGRectNull;        
    }
    
    CGPoint minPoint = {DBL_MAX, DBL_MAX};
    CGPoint maxPoint = {DBL_MIN, DBL_MIN};
    
    for (NSValue* coordValue in coords)
    {
        CGPoint coord = coordValue.CGPointValue;
        
        if (coord.x < minPoint.x)
            minPoint.x = coord.x;
        else if (coord.x > maxPoint.x)
            maxPoint.x = coord.x;
        
        if (coord.y < minPoint.y)
            minPoint.y = coord.y;
        else if (coord.y > maxPoint.y)
            maxPoint.y = coord.y;
    }
    
    CGRect bounds = CGRectMake(minPoint.x, minPoint.y, maxPoint.x-minPoint.x, maxPoint.y-minPoint.y);
    
    return bounds;
}

@end


@implementation ETA_CatalogOfferHotspotModel

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
                                                                                            @"offer": @"offer",
                                                                                            }];
}

@end