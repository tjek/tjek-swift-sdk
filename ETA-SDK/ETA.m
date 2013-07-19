//
//  ETA.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA.h"

#import "ETA_APIClient.h"
#import "ETA_Session.h"


NSString* const ETA_SessionUserIDChangedNotification = @"ETA_SessionUserIDChangedNotification";


@interface ETA ()

@property (nonatomic, readwrite, strong) ETA_APIClient* client;

@property (nonatomic, readwrite, strong) NSString *apiKey;
@property (nonatomic, readwrite, strong) NSString *apiSecret;
@property (nonatomic, readwrite, strong) NSURL *baseURL;

@property (nonatomic, readwrite, strong) NSCache* itemCache;
@end


@implementation ETA
@synthesize client = _client;

+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret
{
    ETA* eta = [[ETA alloc] init];
    
    eta.apiKey = apiKey;
    eta.apiSecret = apiSecret;
    
    return [self etaWithAPIKey:apiKey
                     apiSecret:apiSecret
                       baseURL:nil];
}

+ (instancetype) etaWithAPIKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret baseURL:(NSURL *)baseURL
{
    ETA* eta = [[ETA alloc] init];
    
    eta.apiKey = apiKey;
    eta.apiSecret = apiSecret;
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
    }
    return self;
}

- (void) dealloc
{
    self.client = nil;
}

- (ETA_APIClient*) client
{
    @synchronized(_client)
    {
        if (!_client)
        {
            self.client = [ETA_APIClient clientWithBaseURL:self.baseURL apiKey:self.apiKey apiSecret:self.apiSecret];   
        }
    }
    return _client;
}

- (void) setClient:(ETA_APIClient *)client
{
    if (_client == client)
        return;
    
    [_client removeObserver:self forKeyPath:@"session.user.uuid"];
    
    _client = client;
    
    [_client addObserver:self forKeyPath:@"session.user.uuid" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"session.user.uuid"])
    {
        NSString* old = change[NSKeyValueChangeOldKey];
        old = ([old isEqual:NSNull.null]) ? nil : old;
        
        NSString* new = change[NSKeyValueChangeNewKey];
        new = ([new isEqual:NSNull.null]) ? nil : new;
        
        if (old == new || [old isEqualToString:new])
            return;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_SessionUserIDChangedNotification
                                                            object:self
                                                          userInfo:@{@"oldUserID": change[NSKeyValueChangeOldKey],
                                                                     @"newUserID": change[NSKeyValueChangeNewKey]}];
    }
}

#pragma mark - Connecting

- (void) connect:(void (^)(NSError* error))completionHandler
{
    [self.client startSessionWithCompletion:completionHandler];
}

- (void) connectWithUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(BOOL connected, NSError* error))completionHandler
{
    [self attachUserEmail:email password:password completion:^(NSError *error) {
        if (completionHandler)
        {
            completionHandler(!error, error);
        }
    }];
}




#pragma mark - User Management

- (void) attachUserEmail:(NSString*)email password:(NSString*)password completion:(void (^)(NSError* error))completionHandler
{
    [self.client attachUser:@{@"email":email, @"password":password} withCompletion:completionHandler];
}
- (void) detachUserWithCompletion:(void (^)(NSError* error))completionHandler
{
    [self.client detachUserWithCompletion:completionHandler];
}

- (BOOL) allowsPermission:(NSString*)actionPermission
{
    return [self.client allowsPermission:actionPermission];
}

- (NSString*) attachedUserID
{
    return self.client.session.userID;
}


#pragma mark - Sending API Requests

// the parameters that are derived from the client, that may be overridded by the request
- (NSDictionary*) baseRequestParameters
{
    NSMutableDictionary* params = [@{} mutableCopy];
    [params addEntriesFromDictionary:[self geolocationParameters]];
    
    return params;
}


- (void) api:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError* error, BOOL fromCache))completionHandler
{
    [self api:requestPath type:type parameters:parameters useCache:YES completion:completionHandler];
}

- (void) api:(NSString*)requestPath type:(ETARequestType)type parameters:(NSDictionary*)parameters useCache:(BOOL)useCache completion:(void (^)(id response, NSError* error, BOOL fromCache))completionHandler
{
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
    
    
    if (useCache && completionHandler)
    {
        id cacheResponse = [self getCacheResponseForRequest:requestPath type:type parameters:mergedParameters];
        if (cacheResponse)
        {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                completionHandler(cacheResponse, nil, YES);
            });
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
    if ([ETA_APIEndpoints isValidEndpoint:endpoint])
    {
        // if the penultimate component is a valud endpoint, assume the final item is the id
        itemIDParam = pathComponents[pathComponents.count-1];
    }
    // it wasnt valid - try the final endpoint to use the parameters with
    else
    {
        endpoint = pathComponents[pathComponents.count-1];
        if ([ETA_APIEndpoints isValidEndpoint:endpoint])
        {
            // try to get the multiple-ids parameter
            NSString* multiItemFilterKey = [ETA_APIEndpoints multipleItemsFilterKeyForEndpoint:endpoint];
            if (multiItemFilterKey)
                itemIDParam = parameters[multiItemFilterKey];
            
            
            // if there were no multiple keys, try to get the single key
            NSString* itemFilterKey = [ETA_APIEndpoints itemFilterKeyForEndpoint:endpoint];
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
        NSTimeInterval cacheLifespan = [ETA_APIEndpoints cacheLifespanForEndpoint:endpoint];
        
        NSMutableArray* cachedItems = [@[] mutableCopy];
        
        // go through all the item ids, turn them into erns, and look for them in the cache
        // if any item isnt in the list then return nothing
        BOOL foundAll = YES;
        for (NSString* itemID in itemIDs)
        {
            NSString* itemERN = [ETA_APIEndpoints ernForEndpoint:endpoint withItemID:itemID];
            
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
                id cachedItem = cachedItemDict[@"item"];
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

+ (NSArray*) preferredDistances
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
    if (self.location)
    {
        params[@"r_lat"] = @(self.location.coordinate.latitude);
        params[@"r_lng"] = @(self.location.coordinate.longitude);
        
        if (self.distance)
        {
            NSArray* dists = [[self class] preferredDistances];
            CGFloat minDistance = [dists[0] floatValue];
            CGFloat maxDistance = [[dists lastObject] floatValue];
            
            CGFloat clampedDistance = MIN(MAX(self.distance.floatValue, minDistance), maxDistance);
            params[@"r_radius"] = @(clampedDistance);
        }
        
        params[@"r_sensor"] = @(self.isLocationFromSensor);
    }
    
    return params;
}

- (void) setLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude distance:(CLLocationDistance)distance isFromSensor:(BOOL)isFromSensor
{
    self.location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    self.distance = @(distance);
    self.isLocationFromSensor = isFromSensor;
}




@end
