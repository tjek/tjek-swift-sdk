//
//  ETA_ShoppingList.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_DBSyncModelObject.h"

typedef enum {
    ETA_ShoppingList_Access_Private,
    ETA_ShoppingList_Access_Shared,
    ETA_ShoppingList_Access_Public,
} ETA_ShoppingList_Access;


@interface ETA_ShoppingList : ETA_DBSyncModelObject

@property (nonatomic, readwrite, strong) NSString* name;
@property (nonatomic, readwrite, strong) NSDate* modified;
@property (nonatomic, readwrite, assign) ETA_ShoppingList_Access access;

// uuid and name are required
// if modified is nil, current date is used
+ (instancetype) shoppingListWithUUID:(NSString*)uuid name:(NSString*)name modifiedDate:(NSDate*)modified access:(ETA_ShoppingList_Access)access;

- (NSString*)accessString;

@end
