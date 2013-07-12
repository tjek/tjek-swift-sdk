//
//  ETA_ModelItem.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/11/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "Mantle.h"

@interface ETA_ModelItem : MTLModel <MTLJSONSerializing>

@property (nonatomic, readwrite, strong) NSString* itemID;
@property (nonatomic, readwrite, strong) NSString* ern;

+ (NSString*) ernForItemID:(NSString*)itemID; // base class returns nil

@end
