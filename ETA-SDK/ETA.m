//
//  ETA.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA.h"

#import "ETA_APIClient.h"
#import "ETA_Session.h"


NSString* const ETA_AttachedUserChangedNotification = @"ETA_AttachedUserChangedNotification";

NSString* const ETA_AvoidServerCallKey = @"ETA_AvoidServerCallKey";

NSString* const ETA_APIErrorDomain = @"ETA_APIErrorDomain";
NSString* const ETA_APIError_URLResponseKey = @"ETA_APIError_URLResponseKey";
NSString* const ETA_APIError_ErrorIDKey = @"ETA_APIError_IDKey";
NSString* const ETA_APIError_ErrorObjectKey = @"ETA_APIError_ErrorObjectKey";

typedef enum {
    ETA_APIErrorCode_MissingParameter = 0
} ETA_APIErrorCode;

@interface ETA ()

@property (nonatomic, readwrite, strong) ETA_APIClient* client;

@property (nonatomic, readwrite, strong) NSString *apiKey;
@property (nonatomic, readwrite, strong) NSString *apiSecret;
@property (nonatomic, readwrite, strong) NSString *appVersion;
@property (nonatomic, readwrite, strong) NSURL *baseURL;

@property (nonatomic, readwrite, strong) NSCache* itemCache;

@property (nonatomic, readwrite, assign) BOOL connected;
@property (nonatomic, readwrite, copy) NSString* attachedUserID;

@end

static ETA* ETA_SingletonSDK = nil;

@implementation ETA
@synthesize client = _client;

+ (void)initializeSDKWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion
{
    [self initializeSDKWithAPIKey:apiKey apiSecret:apiSecret appVersion:appVersion baseURL:nil];
}
+ (void)initializeSDKWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion baseURL:(NSURL*)baseURL
{
    if (!apiKey || !apiSecret || !appVersion)
        return;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ETA_SingletonSDK = [ETA etaWithAPIKey:apiKey apiSecret:apiSecret appVersion:(NSString*)appVersion baseURL:baseURL];
    });
}

+ (ETA*)SDK
{
    return ETA_SingletonSDK;
}

+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion
{
    return [self etaWithAPIKey:apiKey
                     apiSecret:apiSecret
                    appVersion:appVersion
                       baseURL:nil];
}

+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret appVersion:(NSString*)appVersion baseURL:(NSURL *)baseURL
{
    ETA* eta = [[ETA alloc] init];
    
    eta.apiKey = apiKey;
    eta.apiSecret = apiSecret;
    eta.appVersion = appVersion;
    if (baseURL)
        eta.baseURL = baseURL;
    return eta;
}


- (instancetype) init
{
    if((self = [super init]))
    {
        self.itemCache = [[NSCache alloc] init];
        
        self.baseURL = [NSURL URLWithString: kETA_APIBaseURLString];
        
        self.verbose = NO;
    }
    return self;
}

- (void) setVerbose:(BOOL)verbose
{
    if (_verbose == verbose)
        return;
    
    _verbose = verbose;
    
    _client.verbose = _verbose;
}

- (ETA_APIClient*) client
{
    @synchronized(_client)
    {
        if (!_client)
        {
            self.client = [ETA_APIClient clientWithBaseURL:self.baseURL apiKey:self.apiKey apiSecret:self.apiSecret appVersion:self.appVersion];
            self.client.verbose = self.verbose;
        }
    }
    return _client;
}

- (void) setClient:(ETA_APIClient *)client
{
    if (_client == client)
        return;
    
    [_client removeObserver:self forKeyPath:@"session"];
    [_client removeObserver:self forKeyPath:@"session.user.uuid"];
    
    _client = client;
    
    [_client addObserver:self forKeyPath:@"session.user.uuid" options:NSKeyValueObservingOptionInitial context:NULL];
    [_client addObserver:self forKeyPath:@"session" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"session"])
    {
        BOOL connected = (self.client.session != nil);
        if (connected != self.connected)
            self.connected = connected;

        
        // watch for changes to the user
        ETA_Session* oldSession = change[NSKeyValueChangeOldKey];
        oldSession = ([oldSession isEqual:NSNull.null]) ? nil : oldSession;
        
        ETA_Session* newSession = change[NSKeyValueChangeNewKey];
        newSession = ([newSession isEqual:NSNull.null]) ? nil : newSession;
        
        ETA_User* oldUser = oldSession.user;
        ETA_User* newUser = newSession.user;
        if (oldUser.uuid == newUser.uuid || [oldUser.uuid isEqualToString:newUser.uuid])
            return;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_AttachedUserChangedNotification
                                                            object:self
                                                          userInfo:@{@"oldUser": (oldUser) ?: NSNull.null,
                                                                     @"newUser": (newUser) ?: NSNull.null }];
    }
    else if ([keyPath isEqualToString:@"session.user.uuid"])
    {
        if ((self.attachedUserID == self.client.session.user.uuid || [self.attachedUserID isEqualToString:self.client.session.user.uuid]) == NO)
        {
            NSLog(@"User %@ => %@", self.attachedUserID, self.client.session.user.uuid);
            self.attachedUserID = self.client.session.user.uuid;
        }
    }
}

#pragma mark - Connecting

- (void) connect:(void (^)(NSError* error))completionHandler
{
    [self.client startSessionWithCompletion:completionHandler];
}


#pragma mark - User Management

- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler
{
    if (!email || !password)
    {
        if (completionHandler)
            completionHandler([NSError errorWithDomain:ETA_APIErrorDomain
                                                  code:ETA_APIErrorCode_MissingParameter
                                              userInfo:@{NSLocalizedDescriptionKey: @"Email and Password required"}]);
        return;
    }
    [self.client attachUser:@{@"email":email, @"password":password} withCompletion:completionHandler];
}
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self.client detachUserWithCompletion:completionHandler];
}
- (void) attachUserWithFacebookToken:(NSString*)facebookToken completion:(void (^)(NSError* error))completionHandler
{
    if (!facebookToken)
    {
        if (completionHandler)
            completionHandler([NSError errorWithDomain:ETA_APIErrorDomain
                                                  code:ETA_APIErrorCode_MissingParameter
                                              userInfo:@{NSLocalizedDescriptionKey: @"Facebook token required"}]);
        return;
    }
    [self.client attachUser:@{@"facebook_token":facebookToken} withCompletion:completionHandler];
}
- (BOOL) allowsPermission:(NSString*)actionPermission
{
    return [self.client allowsPermission:actionPermission];
}

- (ETA_User*) attachedUser
{
    return [self.client.session.user copy];
}

- (BOOL) attachedUserIsFromFacebook
{
    return ([self.client.session.provider caseInsensitiveCompare:@"facebook"] == NSOrderedSame);
}


#pragma mark - Sending API Requests

// the parameters that are derived from the client, that may be overridded by the request
- (NSDictionary*) baseRequestParameters
{
    NSMutableDictionary* params = [@{} mutableCopy];
    [params addEntriesFromDictionary:[self geolocationParameters]];
    
    return params;
}


- (void) api:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(ETA_RequestCompletionBlock)completionHandler
{
    [self api:requestPath type:type parameters:parameters useCache:YES completion:completionHandler];
}

- (void) api:(NSString*)requestPath
        type:(ETARequestType)type
  parameters:(NSDictionary*)parameters
    useCache:(BOOL)useCache
  completion:(ETA_RequestCompletionBlock)completionHandler
{
    NSRange replaceRange = [requestPath rangeOfString:self.baseURL.absoluteString];
    if (replaceRange.location != NSNotFound)
        requestPath = [requestPath stringByReplacingCharactersInRange:replaceRange withString:@""];

    
    // get the base parameters, and override them with those passed in
    NSMutableDictionary* mergedParameters = [[self baseRequestParameters] mutableCopy];
    
    // first take those that are in the string
    NSArray* requestComponents = [requestPath componentsSeparatedByString:@"?"];
    if (requestComponents.count > 1)
    {
        requestPath = requestComponents[0];
        NSArray* keyValues = [requestComponents[1] componentsSeparatedByString:@"&"];
        for (NSString* keyValue in keyValues)
        {
            NSArray* keyAndValueArray = [keyValue componentsSeparatedByString:@"="];
            if (keyAndValueArray.count > 1)
            {
                NSString* key = keyAndValueArray[0];
                NSString* valueStr = keyAndValueArray[1];
                NSArray* valueArr = [valueStr componentsSeparatedByString:@","];
                [mergedParameters setValue:(valueArr.count > 1) ? valueArr : valueStr forKey:key];
            }
        }
    }
    
    // then take those in the dictionary
    [mergedParameters setValuesForKeysWithDictionary:parameters];
    
    // flag to avoid server calls if there is a valid cache response was set, so skip server call
    BOOL cacheAvoidsServer = [mergedParameters[ETA_AvoidServerCallKey] boolValue];
    [mergedParameters removeObjectForKey:ETA_AvoidServerCallKey];
    
    if (useCache && completionHandler)
    {
        id cacheResponse = [self getCacheResponseForRequest:requestPath type:type parameters:mergedParameters];
        if (cacheResponse)
        {
//            dispatch_async(dispatch_get_main_queue(), ^{
            
                completionHandler(cacheResponse, nil, YES);
//            });
            
            if (cacheAvoidsServer)
                return;
        }
    }
    
    [self.client makeRequest:requestPath type:type parameters:mergedParameters completion:^(id response, NSError *error)
    {
        if (useCache)
            [self addJSONItemToCache:response];
        
        if (completionHandler)
            completionHandler(response, error, NO);
    }];
}

#pragma mark - Cache

- (NSArray*)itemIDsFromRequestPath:(NSString*)requestPath parameters:(NSDictionary*)parameters endpointForItems:(NSString**)resultingEndpoint
{
    NSMutableArray* itemIDs = [@[] mutableCopy];
    
    
    // trim the "/" from each end (as they result in empty path components)
    NSString* trimmedPathString = [requestPath stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSArray* pathComponents = [trimmedPathString componentsSeparatedByString:@"/"];
    
    // there must be at least 2 components to get an ern
    if (pathComponents.count < 2)
        return itemIDs;
    
    
    // get the multiple keys from the parameters
    id itemIDParam = nil;
    NSString* endpoint = pathComponents[pathComponents.count-2];
    
    // take the penultimate component and figure out if it is a valid endpoint
    if ([ETA_API isValidEndpoint:endpoint])
    {
        // if the penultimate component is a valud endpoint, assume the final item is the id
        itemIDParam = pathComponents[pathComponents.count-1];
    }
    // it wasnt valid - try the final endpoint to use the parameters with
    else
    {
        endpoint = pathComponents[pathComponents.count-1];
        if ([ETA_API isValidEndpoint:endpoint])
        {
            // try to get the multiple-ids parameter
            NSString* multiItemFilterKey = [ETA_API multipleItemsFilterKeyForEndpoint:endpoint];
            if (multiItemFilterKey)
                itemIDParam = parameters[multiItemFilterKey];
            
            
            // if there were no multiple keys, try to get the single key
            NSString* itemFilterKey = [ETA_API itemFilterKeyForEndpoint:endpoint];
            if (!itemIDParam && itemFilterKey)
                itemIDParam = parameters[itemFilterKey];
        }
    }
    
    
    // We found valid item id(s)! Turn them into a list of erns
    if (itemIDParam && endpoint)
    {
        // turn the item id parameter into an array of strings (it could be an array, a string or a number)
        if ([itemIDParam isKindOfClass:[NSString class]])
        {
            [itemIDs addObjectsFromArray:[itemIDParam componentsSeparatedByString:@","]];
        }
        else if ([itemIDParam isKindOfClass:[NSArray class]])
        {
            for (id subItemID in itemIDParam) {
                if ([subItemID isKindOfClass:[NSNumber class]] || [subItemID isKindOfClass:[NSString class]])
                    [itemIDs addObject:[NSString stringWithFormat:@"%@", subItemID]];
            }
        }
        else if ([itemIDParam isKindOfClass:[NSNumber class]])
        {
            [itemIDs addObject:[NSString stringWithFormat:@"%@", itemIDParam]];
        }
        
        *resultingEndpoint = endpoint;
    }
    
    return itemIDs;
}

- (id) getCacheResponseForRequest:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters
{
    if (type != ETARequestTypeGET)
        return nil;
    
    /*
     /v2/catalogs?catalog_id=1234
     /v2/catalogs/1234/?something
       = ["ern:catalog:1234"]
     
     /v2/catalogs?catalog_ids=1234,5678
       = ["ern:catalog:1234", "ern:catalog:5678"]
     
     /v2/catalogs/1234/stores/1234
     /v2/catalogs?store_id=1234
       = []
     */
    NSString* endpoint = nil;
    NSArray* itemIDs = [self itemIDsFromRequestPath:requestPath parameters:parameters endpointForItems:&endpoint];
    if (itemIDs.count && endpoint)
    {
        NSTimeInterval nowTimestamp = [NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval cacheLifespan = [ETA_API cacheLifespanForEndpoint:endpoint];
        
        NSMutableArray* cachedItems = [@[] mutableCopy];
        
        // go through all the item ids, turn them into erns, and look for them in the cache
        // if any item isnt in the list then return nothing
        BOOL foundAll = YES;
        for (NSString* itemID in itemIDs)
        {
            NSString* itemERN = [ETA_API ernForEndpoint:endpoint withItemID:itemID];
            
            NSDictionary* cachedItemDict = (itemERN) ? [self.itemCache objectForKey:itemERN] : nil;
            // item not in cache
            if (!cachedItemDict)
            {
                foundAll = NO;
                break;
            }
            // item in cache
            else
            {
                id cachedItem = [cachedItemDict[@"item"] copy];
                // invalid item, or out of date. remove from cache and fail
                if (!cachedItem || (nowTimestamp - [cachedItemDict[@"timestamp"] doubleValue]) > cacheLifespan)
                {
                    [self.itemCache removeObjectForKey:itemERN];
                    foundAll = NO;
                    break;
                }
                // yay - it's in the cache
                else
                {
                    [cachedItems addObject:cachedItem];
                }
            }
        }
        
        if (foundAll)
            return cachedItems;
    }
    return nil;
}

- (void) addJSONItemToCache:(id)jsonItem
{
    if ([jsonItem isKindOfClass:[NSArray class]])
    {
        for (id subitem in jsonItem)
        {
            [self addJSONItemToCache:subitem];
        }
    }
    else if ([jsonItem isKindOfClass:[NSDictionary class]])
    {
        NSString* ern = jsonItem[@"ern"];
        if (ern)
        {
            [self.itemCache setObject:@{ @"item": jsonItem, @"timestamp":@([NSDate timeIntervalSinceReferenceDate]) }
                               forKey:ern];
        }
    }
}

#pragma mark - Geolocation

+ (NSArray*) preferredRadiuses
{
    return @[ @100, @150, @200, @250, @300, @350,
              @400, @450, @500, @600, @700, @800,
              @900, @1000, @1500, @2000, @2500,
              @3000, @3500, @4000, @4500, @5000,
              @5500, @6000, @6500, @7000, @7500,
              @8000, @8500, @9000, @9500, @10000,
              @15000, @20000, @25000, @30000, @35000,
              @40000, @45000, @50000, @55000, @60000,
              @65000, @70000, @75000, @80000, @85000,
              @90000, @95000, @100000, @200000, @300000,
              @400000, @500000, @600000, @700000 ];
}

- (NSDictionary*) geolocationParameters
{
    NSMutableDictionary* params = [@{} mutableCopy];
    if (self.geolocation)
    {
        params[@"r_lat"] = @(self.geolocation.coordinate.latitude);
        params[@"r_lng"] = @(self.geolocation.coordinate.longitude);
        
        if (self.radius)
        {
            NSArray* radiuses = [[self class] preferredRadiuses];
            CGFloat minRadius = [radiuses[0] floatValue];
            CGFloat maxRadius = [[radiuses lastObject] floatValue];
            
            CGFloat clampedRadius = MIN(MAX(self.radius.floatValue, minRadius), maxRadius);
            params[@"r_radius"] = @(clampedRadius);
        }
        
        params[@"r_sensor"] = @(self.isLocationFromSensor);
    }
    
    return params;
}

- (void) setLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude radius:(CLLocationDistance)radius isFromSensor:(BOOL)isFromSensor
{
    self.geolocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    self.radius = @(radius);
    self.isLocationFromSensor = isFromSensor;
}



#pragma mark - Errors

+ (NSDictionary*) errors
{
    static NSDictionary* errors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        errors = @{
                   // Session errors
                   @(1100): @"ETA_Error_SessionError",
                   @(1101): @"ETA_Error_SessionTokenExpired",
                   @(1102): @"ETA_Error_SessionInvalidAPIKey",
                   @(1103): @"ETA_Error_SessionMissingSignature",
                   @(1104): @"ETA_Error_SessionInvalidSignature",
                   @(1105): @"ETA_Error_SessionTokenNotAllowed",
                   @(1106): @"ETA_Error_SessionMissingOrigin",
                   @(1107): @"ETA_Error_SessionMissingToken",
                   @(1108): @"ETA_Error_SessionInvalidToken",
                   
                   
                   // Authentication
                   @(1200): @"ETA_Error_AuthenticationError",
                   @(1201): @"ETA_Error_AuthenticationInvalidCredentials",
                   @(1202): @"ETA_Error_AuthenticationNoUser",
                   @(1203): @"ETA_Error_AuthenticationEmailNotVerified",
                   
                   
                   // Authorization
                   @(1300): @"ETA_Error_AuthorizationError",
                   @(1301): @"ETA_Error_AuthorizationActionNotAllowed",
                   
                   
                   // Missing information
                   @(1400): @"ETA_Error_InfoRequestInvalid",
                   @(1401): @"ETA_Error_InfoMissingGeolocation",
                   @(1402): @"ETA_Error_InfoMissingRadius",
                   @(1411): @"ETA_Error_InfoMissingAuthentication",
                   @(1431): @"ETA_Error_InfoMissingEmail",
                   @(1432): @"ETA_Error_InfoMissingBirthday",
                   @(1433): @"ETA_Error_InfoMissingGender",
                   @(1434): @"ETA_Error_InfoMissingLocale",
                   @(1435): @"ETA_Error_InfoMissingName",
                   @(1440): @"ETA_Error_InfoResourceNotFound",
                   
                   // Invalid information
                   @(1500): @"ETA_Error_InfoInvalid",
                   @(1501): @"ETA_Error_InfoInvalidResourceID",
                   @(1530): @"ETA_Error_InfoResourceDuplication",
                   @(1566): @"ETA_Error_InfoInvalidBodyData",
                   
                   // Internal corruption of data
                   @(2000): @"ETA_Error_InternalIntegrityError",
                   @(2010): @"ETA_Error_InternalSearchError",
                   @(2015): @"ETA_Error_InternalNonCriticalError",
                   
                   // Misc.
                   @(4000): @"ETA_Error_MiscActionNotExists",
                   };
    });
    return errors;
}
+ (NSString*) errorForCode:(NSInteger)errorCode
{
    return [[ETA errors] objectForKey:@(errorCode)];
}

@end
