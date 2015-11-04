//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2015 ShopGun. All rights reserved.


#import "SGN_APIErrors.h"




@implementation NSError (SGN_ErrorUtilities)

- (BOOL) SGN_isNetworkError
{
    if (![self.domain isEqualToString:NSURLErrorDomain])
        return NO;
    
    switch (self.code)
    {
        case NSURLErrorTimedOut:
        case NSURLErrorCannotFindHost:
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorInternationalRoamingOff:
        case NSURLErrorCallIsActive:
        case NSURLErrorDataNotAllowed:
            return YES;
        default:
            return NO;
    }
}

@end









#pragma mark - NSError + NSURLResponse Additions


NSString* const SGN_Error_UserInfo_URLResponseKey = @"SGN_Error_UserInfo_URLResponseKey";

@implementation NSError (NSURLResponse_Additions)

- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(nullable NSDictionary *)dict urlResponse:(nullable NSURLResponse*)urlResponse
{
    NSDictionary* userInfo = dict;
    if (urlResponse)
    {
        NSMutableDictionary* modifiedUserInfo = [dict mutableCopy] ?: [NSMutableDictionary new];
        [modifiedUserInfo setValue:urlResponse forKey:SGN_Error_UserInfo_URLResponseKey];
        
        userInfo = modifiedUserInfo;
    }
    
    return [self initWithDomain:domain code:code userInfo:userInfo];
}

+ (instancetype) errorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(nullable NSDictionary *)dict urlResponse:(nullable NSURLResponse*)urlResponse
{
    return [[self alloc] initWithDomain:domain code:code userInfo:dict urlResponse:urlResponse];
}


- (NSURLResponse*) URLResponse
{
    return self.userInfo[SGN_Error_UserInfo_URLResponseKey];
}

- (NSInteger) HTTPStatusCode
{
    NSURLResponse* urlResponse = self.URLResponse;
    if ([urlResponse respondsToSelector:@selector(statusCode)])
        return [(NSHTTPURLResponse*)urlResponse statusCode];
    else
        return -1;
}

- (NSURL*) requestURL
{
    NSURLResponse* urlResponse = self.URLResponse;
    if ([urlResponse respondsToSelector:@selector(URL)])
        return urlResponse.URL;
    else
        return nil;
}

- (NSInteger) retryAfterSeconds
{
    NSURLResponse* urlResponse = self.URLResponse;
    if ([urlResponse respondsToSelector:@selector(allHeaderFields)])
    {
        NSInteger retryAfter = [[(NSHTTPURLResponse*)urlResponse allHeaderFields][@"Retry-After"] integerValue];
        return MAX(retryAfter, 0);
    }
    else
    {
        return 0;
    }
}

@end









#pragma mark - API Response Errors
///---------------------------------------------
/// @name API Response Errors
///---------------------------------------------


NSString* const SGN_APIResponseErrorDomain = @"SGN_APIResponseErrorDomain";
NSString* const SGN_APIResponseError_UserInfo_APIErrorIDKey = @"SGN_APIResponseError_UserInfo_APIErrorIDKey";
NSString* const SGN_APIResponseError_UserInfo_ResponseObjectKey = @"SGN_APIResponseError_UserInfo_ResponseObjectKey";


@implementation NSError (SGN_APIResponseError)

+ (instancetype) SGN_errorWithAPIResponseCode:(SGN_APIResponseErrorCode)errorCode apiErrorID:(nullable NSString*)errorID userInfo:(NSDictionary*)dict urlResponse:(nullable NSURLResponse*)urlResponse
{
    NSDictionary* userInfo = dict;
    if (errorID)
    {
        NSMutableDictionary* modifiedUserInfo = [userInfo mutableCopy] ?: [NSMutableDictionary new];
        [modifiedUserInfo setValue:errorID forKey:SGN_APIResponseError_UserInfo_APIErrorIDKey];
        
        userInfo = modifiedUserInfo;
    }
    
    return [self errorWithDomain:SGN_APIResponseErrorDomain
                            code:errorCode
                        userInfo:userInfo
                     urlResponse:urlResponse];
}

+ (nullable instancetype) SGN_errorWithAPIJSONResponse:(NSDictionary*)responseObject urlResponse:(nullable NSURLResponse*)urlResponse
{
    // check if the obj is a valid dictionary
    if (![responseObject isKindOfClass:NSDictionary.class])
        return nil;
    
    
    // we have been given a urlResponse, and the urlResponse doesnt have an error (4xx/5xx) status code, so this isnt an SGN error
    // http://httpstatus.es/
    if (urlResponse && [urlResponse isKindOfClass:NSHTTPURLResponse.class])
    {
        NSInteger statusCode = ((NSHTTPURLResponse*)urlResponse).statusCode;
        if (statusCode < 400 || statusCode >= 600)
            return nil;
    }
    
    
    // check if the obj has the required error keys
    NSString* errCode = responseObject[@"code"];
    NSString* errID = responseObject[@"id"];
    if (!errCode || !errID)
        return nil;
    
    
    // generate the user info for this error
    NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
    
    id message = responseObject[@"message"];
    id details = responseObject[@"details"];
    id notes = responseObject[@"@note.1"];
    
    [userInfo setValue:message ? [NSString stringWithFormat:@"%@", message] : nil forKey:NSLocalizedDescriptionKey];
    [userInfo setValue:details ? [NSString stringWithFormat:@"%@", details] : nil forKey:NSLocalizedFailureReasonErrorKey];
    [userInfo setValue:notes ? [NSString stringWithFormat:@"%@",notes] : nil forKey:NSLocalizedRecoverySuggestionErrorKey];
    [userInfo setValue:responseObject forKey:SGN_APIResponseError_UserInfo_ResponseObjectKey];
    
    
    return [self SGN_errorWithAPIResponseCode:errCode.integerValue
                                   apiErrorID:errID
                                     userInfo:userInfo
                                  urlResponse:urlResponse];
}

- (NSDictionary*) SGN_apiResponseObject
{
    return self.userInfo[SGN_APIResponseError_UserInfo_ResponseObjectKey];
}

- (NSString*) SGN_apiErrorID
{
    return self.userInfo[SGN_APIResponseError_UserInfo_APIErrorIDKey];
}


- (BOOL) SGN_isAPIResponseError
{
    return [self.domain isEqualToString:SGN_APIResponseErrorDomain];
}

- (BOOL) SGN_doesAPIResponseErrorRequireNewSession
{
    if (![self SGN_isAPIResponseError])
        return NO;
    
    switch (self.code) {
        case SGN_APIError_SessionTokenExpired:
        case SGN_APIError_SessionInvalidSignature:
        case SGN_APIError_SessionMissingToken:
        case SGN_APIError_SessionInvalidToken:
            return YES;
        default:
            return NO;
    }
}

- (BOOL) SGN_isMaintenanceAPIResponseError
{
    if (![self SGN_isAPIResponseError])
        return NO;
    
    return (self.code >= SGN_APIError_MaintenanceError && self.code <= SGN_APIError_MaintenanceError_END);
}

@end






#pragma mark - SDK Errors
///---------------------------------------------
/// @name SDK Errors
///---------------------------------------------


NSString* const SGN_SDKErrorDomain = @"SGN_SDKErrorDomain";


@implementation NSError (SGN_SDKResponseError)

+ (instancetype) SGN_errorWithSDKCode:(SGN_SDKErrorCode)errorCode message:(NSString*)message
{
    NSDictionary* userInfo = message ? @{NSLocalizedDescriptionKey:message} : nil;
    return [self SGN_errorWithSDKCode:errorCode userInfo:userInfo];
}

+ (instancetype) SGN_errorWithSDKCode:(SGN_SDKErrorCode)errorCode userInfo:(NSDictionary*)userInfo
{
    return [self errorWithDomain:SGN_SDKErrorDomain
                            code:errorCode
                        userInfo:userInfo];
}

- (BOOL) SGN_isSDKError
{
    return [self.domain isEqualToString:SGN_SDKErrorDomain];
}

@end

