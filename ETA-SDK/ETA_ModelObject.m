//
//  ETA_ModelObject.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ModelObject.h"
#import "ETA_APIEndpoints.h"

@implementation ETA_ModelObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{ @"uuid": @"id",
              @"ern": @"ern",
            };
}

+ (NSValueTransformer *)uuidJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^id(id jsonVal) {
        if ([jsonVal isKindOfClass:[NSString class]])
            return jsonVal;
        else if ([jsonVal isKindOfClass:[NSNumber class]])
            return [jsonVal stringValue];
        else
            return nil;
    }];
}

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZ";
        
    });
    return dateFormatter;
}

+ (NSString*) APIEndpoint {
    NSAssert(NO, @"ETA_ModelObject subclasses must define an APIEndpoint");
    return nil;
}

+ (NSString*) ernForItemID:(NSString*)itemID
{
    return [ETA_APIEndpoints ernForEndpoint:self.APIEndpoint withItemID:itemID];
}


+ (instancetype) objectFromJSONDictionary:(NSDictionary*)JSONDictionary
{
    if (!JSONDictionary)
        return nil;
    else
        return [MTLJSONAdapter modelOfClass:[self class] fromJSONDictionary:JSONDictionary error:nil];
}

- (NSDictionary*) JSONDictionary
{
    return [MTLJSONAdapter JSONDictionaryFromModel:self];
}


#pragma mark - UUID & ERN

- (void) setUuid:(NSString *)uuid
{
    if (_uuid == uuid || (_uuid && [_uuid isEqualToString:uuid]))
        return;
    
    _uuid = uuid;
    
    self.ern = [[self class] ernForItemID:_uuid];
    
}

- (void) setErn:(NSString *)ern
{
    if (_ern == ern || (_ern && [_ern isEqualToString:ern]))
        return;
    
    _ern = ern;
    
    self.uuid = [[_ern componentsSeparatedByString:@":"] lastObject];
}


- (NSString*) description
{
    NSString* JSON = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:self.JSONDictionary
                                                                                     options:NSJSONWritingPrettyPrinted
                                                                                       error:nil]
                                           encoding: NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass([self class]), JSON];
}

@end
