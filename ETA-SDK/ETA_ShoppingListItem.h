//
//  ETA_ShoppingListItem.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_DBSyncModelObject.h"

@interface ETA_ShoppingListItem : ETA_DBSyncModelObject

@property (nonatomic, readwrite, strong) NSDate* modified;
@property (nonatomic, readwrite, strong) NSString* name; // actually 'description', but that's a special case in cocoa
@property (nonatomic, readwrite, assign) NSInteger count;
@property (nonatomic, readwrite, assign) BOOL tick;
@property (nonatomic, readwrite, strong) NSString* offerID;
@property (nonatomic, readwrite, strong) NSString* creator;
@property (nonatomic, readwrite, strong) NSString* shoppingListID;

// the shopping list item that comes before this item in the user-defined sort order
// null if undefined. "" if first item in list.
@property (nonatomic, readwrite, strong) NSString* prevItemID;

// calculated sort order id based on the prevItemID. Not sent to server.
// -1 if not set.
@property (nonatomic, readwrite, assign) NSInteger orderIndex;

@end
