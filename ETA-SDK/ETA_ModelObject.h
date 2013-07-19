//
//  ETA_ModelObject.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "Mantle.h"

@interface ETA_ModelObject : MTLModel <MTLJSONSerializing>

// setting either uuid or ern will keep the other updated
@property (nonatomic, readwrite, strong) NSString* uuid;
@property (nonatomic, readwrite, strong) NSString* ern;


+ (NSString*) APIEndpoint; // base class returns nil.
+ (NSString*) ernForItemID:(NSString*)itemID; //uses the API Endpoint to generate the ern

+ (instancetype) objectFromJSONDictionary:(NSDictionary*)JSONDictionary;
- (NSDictionary*) JSONDictionary;

+ (NSDateFormatter *)dateFormatter;

@end
