//
//  ETA_ShoppingList.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "MTLModel.h"

@interface ETA_ShoppingList : MTLModel

@property (nonatomic, readwrite, strong) NSString* uuid;
@property (nonatomic, readwrite, strong) NSDate* modified;
@property (nonatomic, readwrite, strong) NSString* ern;
@property (nonatomic, readwrite, strong) NSString* name;
@property (nonatomic, readwrite, strong) NSString* access;

@property (nonatomic, readwrite, strong) NSMutableArray* items;

@end
