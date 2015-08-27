//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2015 ShopGun. All rights reserved.


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


#pragma mark - NSError + Utilites
///---------------------------------------------
/// @name NSError + Utilities
///---------------------------------------------

@interface NSError (SGN_ErrorUtilities)

- (BOOL) SGN_isNetworkError;

@end




#pragma mark - NSError + NSURLResponse Additions
///---------------------------------------------
/// @name NSError + NSURLResponse Additions
///---------------------------------------------


extern NSString* const SGN_Error_UserInfo_URLResponseKey;
/**
 Utility methods for attaching and accessing a URL Response object to an error's userInfo
 */
@interface NSError (NSURLResponse_Additions)

- (instancetype) initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(nullable NSDictionary *)dict urlResponse:(nullable NSURLResponse*)urlResponse;

+ (instancetype) errorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(nullable NSDictionary *)dict urlResponse:(nullable NSURLResponse*)urlResponse;


@property (readonly, nullable) NSURLResponse* URLResponse;
@property (readonly) NSInteger HTTPStatusCode; // -1 if URLResponse is `nil` or doesnt contain an httpStatusCode
@property (readonly, nullable) NSURL* requestURL; // the URL that triggered the URLResponse
@property (readonly) NSInteger retryAfterSeconds; // number of seconds the urlResponse suggests you wait until retrying. 0 if not set.

@end






#pragma mark - API Response Errors
///---------------------------------------------
/// @name API Response Errors
///---------------------------------------------

extern NSString* const SGN_APIResponseErrorDomain;
extern NSString* const SGN_APIResponseError_UserInfo_ResponseObjectKey;
extern NSString* const SGN_APIResponseError_UserInfo_APIErrorIDKey;
/**
 *  SGN_APIResponseErrorCode
 *  API Request Error Codes - These are returned from the server in an NSError with the domain `SGN_APIRequestErrorDomain`.
 */
typedef NS_ENUM(NSInteger, SGN_APIResponseErrorCode)
{
    // Session errors
    SGN_APIError_SessionError                       = 1100, // Session error.
    SGN_APIError_SessionTokenExpired                = 1101, // Token has expired. You must create a new one to continue.
    SGN_APIError_SessionInvalidAPIKey               = 1102, // Invalid API key. Could not find app matching your api key.
    SGN_APIError_SessionMissingSignature            = 1103, // Missing signature. Only webpages are allowed to rely on domain name matching. Your request did not send the HTTP_HOST header, so you would have to supply a signature. See docs.
    SGN_APIError_SessionInvalidSignature            = 1104, // Invalid signature. Signature given but did not match.
    SGN_APIError_SessionTokenNotAllowed             = 1105, // Token not allowed. This token can not be used with this app. Ensure correct domain rules in app settings.
    SGN_APIError_SessionMissingOrigin               = 1106, // Missing origin header. This token can not be used without a valid Origin header.
    SGN_APIError_SessionMissingToken                = 1107, // Missing token. No token found in request to an endpoint that requires a valid token.
    SGN_APIError_SessionInvalidToken                = 1108, // Invalid token. Token is not valid.
    SGN_APIError_SessionInvalidOriginHeader         = 1110, // Invalid Origin header. Origin header does not match API App settings.
    SGN_APIError_SessionError_END                   = 1199,

    
    // Authentication
    SGN_APIError_AuthenticationError                = 1200, // Authentication error.
    SGN_APIError_AuthenticationInvalidCredentials   = 1201, // User authorization failed. Did you supply the correct user credentials?
    SGN_APIError_AuthenticationNoUser               = 1202, // User authorization failed. User not verified.
    SGN_APIError_AuthenticationEmailNotVerified     = 1203, // User authorization failed. Supplied email not verfied. Check inbox.
    SGN_APIError_AuthenticationError_END            = 1299,
    
    
    // Authorization
    SGN_APIError_AuthorizationError                 = 1300, // Authorization error.
    SGN_APIError_AuthorizationActionNotAllowed      = 1301, // Action not allowed within current session (permission error)
    SGN_APIError_AuthorizationError_END             = 1399,

    
    
    // Missing Information
    SGN_APIError_InfoMissingError                   = 1400, // Request invalid due to missing information.
    SGN_APIError_InfoMissingGeolocation             = 1401, // Missing request location. This call requires a request location. See documentation.
    SGN_APIError_InfoMissingRadius                  = 1402, // Missing request radius. This call requires a request radius. See documentation.
    SGN_APIError_InfoMissingAuthentication          = 1411, // Missing authentication information You might need to supply authentication credentials in this request. See documentation.
    
    // Login specific information (facebook info could be missing, special code for each field)
    SGN_APIError_InfoMissingEmail                   = 1431, // Missing email property. You might be able to specify this manually. See documentation
    SGN_APIError_InfoMissingBirthday                = 1432, // Missing birthday property. You might be able to specify this manually. See documentation
    SGN_APIError_InfoMissingGender                  = 1433, // Missing gender property. You might be able to specify this manually. See documentation
    SGN_APIError_InfoMissingLocale                  = 1434, // Missing locale property. You might be able to specify this manually. See documentation
    SGN_APIError_InfoMissingName                    = 1435, // Missing name property. You might be able to specify this manually. See documentation
    SGN_APIError_InfoMissingResourceNotFound        = 1440, // Requested resource(s) not found
    SGN_APIError_InfoMissingResourceDeleted         = 1441, // Request resource not found because it has been deleted
    SGN_APIError_InfoMissingError_END               = 1499,
    
    
    // Invalid Information
    SGN_APIError_InfoInvalid                        = 1500, // Invalid information
    SGN_APIError_InfoInvalidResourceID              = 1501, // Invalid resource id
    SGN_APIError_InfoInvalidResourceDuplication     = 1530, // Duplication of resource
    SGN_APIError_InfoInvalidBodyData                = 1566, // Invalid body data. Ensure body data is of valid syntax, and that you send a correct Content-Type header
    SGN_APIError_InfoInvalidProtocol                = 1568, // Invalid protocol
    SGN_APIError_InfoInvalid_END                    = 1599,

    
    // Rate Control
    SGN_APIError_RateControlError                   = 1600, // You are sending to many requests in a short period of time
    SGN_APIError_RateControlLimited                 = 1601, // You are being rate limited
    SGN_APIError_RateControlError_END               = 1600,

    
    // Internal Corruption Of Data
    SGN_APIError_InternalIntegrityError             = 2000, // Internal integrity error. Please contact support with error id.
    SGN_APIError_InternalSearchError                = 2010, // Internal search error. Please contact support with error id.
    SGN_APIError_InternalNonCriticalError           = 2015, // Non-critical internal error. System trying to autofix. Please repeat request.
    SGN_APIError_InternalIntegrityError_END         = 2099,
    
    
    // Misc.
    SGN_APIError_MiscActionNotExists                = 4000, // Action does not exist. Error message describes problem
    SGN_APIError_MiscError_END                      = 4099,
    
    
    // Maintenance
    SGN_APIError_MaintenanceError                   = 5000, // Service is unavailable. We are working on it.
    SGN_APIError_MaintenanceErrorServiceDown        = 5010, // Service is down for maintainance (don't send requests)
    SGN_APIError_MaintenanceErrorFeatureDown        = 5020, // Feature is down for maintainance (Dont send same request again)
    SGN_APIError_MaintenanceError_END               = 5999,
};




@interface NSError (SGN_APIResponseError)

+ (instancetype) SGN_errorWithAPIResponseCode:(SGN_APIResponseErrorCode)errorCode apiErrorID:(nullable NSString*)errorID userInfo:(NSDictionary*)dict urlResponse:(nullable NSURLResponse*)urlResponse;

/**
 *  Turn API JSON response into an SGN error object, or `nil` if not an error object.
 *
 *  If the response object isnt a valid dictionary, or it doesnt contain a 'code' or 'id' key, this isnt an SGN error.
 *  If a urlResponse is given, and its status code is not 4xx/5xx, this isnt an SGN error.
 *
 *  @param responseObject The JSON dictionary object that contains the details of the API error
 *  @param urlResponse    The optional URL response
 *
 *  @return An API Error object, whose properties were read from the `responseObject`. Can return `nil`.
 */
+ (nullable instancetype) SGN_errorWithAPIJSONResponse:(NSDictionary*)responseObject urlResponse:(nullable NSURLResponse*)urlResponse;

/**
 *  The JSON object that was passed into `SGN_errorWithAPIJSONResponse:urlResponse`, or nil if none available
 */
@property (readonly, nullable) NSDictionary* SGN_apiResponseObject;

@property (readonly, nullable) NSString* SGN_apiErrorID;


/**
 *  Does the error have the domain `SGN_APIResponseErrorDomain`
 *
 *  @return `YES` if it's an APIResponse error
 */
- (BOOL) SGN_isAPIResponseError;


/**
 *  Is the error an APIResponseError, and does the code match with those that require the session to be invalidated
 *
 *  @return `YES` if is APIResponse error, and has a matching code.
 */
- (BOOL) SGN_doesAPIResponseErrorRequireNewSession;


- (BOOL) SGN_isMaintenanceAPIResponseError;


@end




#pragma mark - SDK Errors
///---------------------------------------------
/// @name SDK Errors
///---------------------------------------------

extern NSString* const SGN_SDKErrorDomain;

/**
 *  SGN_SDKErrorCode
 *  SDK Error Codes - These are created by the native SDK in an NSError with the domain `SGN_SDKErrorDomain`.
 */
typedef NS_ENUM(NSInteger, SGN_SDKErrorCode)
{
    SGN_SDKError_MissingParameter       = -1000
};


@interface NSError (SGN_SDKResponseError)

+ (instancetype) SGN_errorWithSDKCode:(SGN_SDKErrorCode)errorCode message:(nullable NSString*)message;
+ (instancetype) SGN_errorWithSDKCode:(SGN_SDKErrorCode)errorCode userInfo:(nullable NSDictionary*)userInfo;

/**
 *  Does the error have the domain `SGN_SDKErrorDomain`
 *
 *  @return `YES` if it's an SDK error
 */
- (BOOL) SGN_isSDKError;

@end


NS_ASSUME_NONNULL_END
