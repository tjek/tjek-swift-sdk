//
//  NSValueTransformer+ETAPredefinedValueTransformers.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "NSValueTransformer+ETAPredefinedValueTransformers.h"
#import "MTLValueTransformer.h"

NSString * const ETA_HexColor_ValueTransformerName = @"ETA_HexColor_ValueTransformerName";
NSString * const ETA_APIDate_ValueTransformerName = @"ETA_APIDate_ValueTransformerName";


@implementation NSValueTransformer (ETAPredefinedValueTransformers)

+ (void)load {
	@autoreleasepool {
        
        MTLValueTransformer* hexColorTransformer = [MTLValueTransformer
                                                    reversibleTransformerWithForwardBlock: ^UIColor*(NSString* colorStr)
                                                    {
                                                        if ([colorStr hasPrefix:@"#"])
                                                            colorStr = [colorStr substringFromIndex:1];
                                                        if (!colorStr)
                                                            return nil;
                                                        
                                                        NSScanner *scanner = [NSScanner scannerWithString:colorStr];
                                                        unsigned hexInt;
                                                        if (![scanner scanHexInt:&hexInt])
                                                            return nil;
                                                        
                                                        int r = (hexInt >> 16) & 0xFF;
                                                        int g = (hexInt >> 8) & 0xFF;
                                                        int b = (hexInt) & 0xFF;
                                                        
                                                        return [UIColor colorWithRed:r / 255.0f
                                                                               green:g / 255.0f
                                                                                blue:b / 255.0f
                                                                               alpha:1.0f];
                                                    }
                                                    reverseBlock:^NSString*(UIColor* colorObj)
                                                    {
                                                        UInt32 rgbHex = 0;
                                                        CGFloat r,g,b,a;
                                                        if ([colorObj getRed:&r green:&g blue:&b alpha:&a])
                                                        {
                                                            r = MIN(MAX(r, 0.0f), 1.0f);
                                                            g = MIN(MAX(g, 0.0f), 1.0f);
                                                            b = MIN(MAX(b, 0.0f), 1.0f);
                                                            
                                                            rgbHex = (UInt32) ((((int)roundf(r * 255)) << 16)
                                                                               | (((int)roundf(g * 255)) << 8)
                                                                               | (((int)roundf(b * 255))));
                                                        }
                                                        else
                                                            return nil;
                                                        
                                                        return [NSString stringWithFormat:@"%0.6lX", rgbHex];
                                                    }];
		
		[NSValueTransformer setValueTransformer:hexColorTransformer forName:ETA_HexColor_ValueTransformerName];
        
        
        
        NSDateFormatter* df = [[NSDateFormatter alloc] init];
        df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        df.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZ";
		MTLValueTransformer *apiDateValueTransformer = [MTLValueTransformer
                                                        reversibleTransformerWithForwardBlock:^NSDate*(NSString *str)
                                                        {
                                                            return [df dateFromString:str];
                                                        }
                                                        reverseBlock:^NSString*(NSDate *date)
                                                        {
                                                            return [df stringFromDate:date];
                                                        }];
        
		[NSValueTransformer setValueTransformer:apiDateValueTransformer forName:ETA_APIDate_ValueTransformerName];
	}
}

@end
