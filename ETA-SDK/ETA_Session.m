//
//  ETA_Session.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_Session.h"

//#import "ETA_APIClient.h"
#import "MTLValueTransformer.h"

static NSTimeInterval const kETA_SoonToExpireTimeInterval = 86400; // 1 day

@implementation ETA_Session
//
//+ (void) createSessionUsingClient:(ETA_APIClient*)client withCallback:(void (^)(ETA_Session* session, NSError* error))callback
//{
//    [client postPath:@"/v2/sessions"
//          parameters: @{ @"api_key": (client.apiKey) ?: [NSNull null] }
//             success:^(AFHTTPRequestOperation *operation, id responseObject) {
//                 NSError* err = nil;
//                 ETA_Session* session = [[ETA_Session alloc] initWithDictionary:responseObject error:&err];
//                 
//                 callback(session, err);
//             }
//             failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//                 callback(nil, error);
//             }];
//}
//- (void) renewUsingClient:(ETA_APIClient*)client withCallback:(void (^)(NSError* error))callback
//{
//    //[client updateHeadersForSession:self];
//    
//    [client putPath:@"/v2/sessions" parameters:<#(NSDictionary *)#> success:<#^(AFHTTPRequestOperation *operation, id responseObject)success#> failure:<#^(AFHTTPRequestOperation *operation, NSError *error)failure#>
//}
//- (void) updateUsingClient:(ETA_APIClient*)client withCallback:(void (^)(NSError* error))callback
//{
//
//}

+ (NSDateFormatter *)dateFormatter {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZ";
    return dateFormatter;
}

+ (NSValueTransformer *)expiresJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [self.dateFormatter dateFromString:str];
    } reverseBlock:^(NSDate *date) {
        return [self.dateFormatter stringFromDate:date];
    }];
}



+ (NSDictionary *)JSONKeyPathsByPropertyKey {
//    return [super.JSONKeyPathsByPropertyKey mtl_dictionaryByAddingEntriesFromDictionary:@{
    return @{
//             @"expires": @"expires"
//             @"token": @"token",
//             @"reporterLogin": @"user.login",
//             @"assignee": @"assignee",
//             @"updatedAt": @"updated_at"
             };
}


- (BOOL) willExpireSoon
{
    return ([self.expires timeIntervalSinceNow] <= kETA_SoonToExpireTimeInterval); // will expire in less than a day
}

@end
