//
//  ETA_ModelObject.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

@import Mantle;

@interface ETA_ModelObject : MTLModel <MTLJSONSerializing>

// setting either uuid or ern will keep the other updated
@property (nonatomic, readwrite, strong, nonnull) NSString* uuid; // will always be lowercase, no matter the input case
@property (nonatomic, readwrite, strong, nonnull) NSString* ern;


+ (nullable NSString*) APIEndpoint; // base class returns nil.
+ (nullable NSString*) ernForItemID:(nullable NSString*)itemID; //uses the API Endpoint to generate the ern

+ (nullable instancetype) objectFromJSONDictionary:(nullable NSDictionary*)JSONDictionary;
- (nullable NSDictionary*) JSONDictionary;

+ (nullable NSArray*) objectsFromJSONArray:(nullable NSArray*)JSONArray;

@end
