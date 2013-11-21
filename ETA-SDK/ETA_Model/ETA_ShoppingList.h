//
//  ETA_ShoppingList.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_DBSyncModelObject.h"

extern NSString* const kETA_ShoppingList_MetaThemeKey;

typedef enum {
    ETA_ShoppingList_Access_Private,
    ETA_ShoppingList_Access_Shared,
    ETA_ShoppingList_Access_Public,
} ETA_ShoppingList_Access;

typedef enum {
    ETA_ShoppingList_Type_ShoppingList,
    ETA_ShoppingList_Type_WishList,
} ETA_ShoppingList_Type;

@interface ETA_ShoppingList : ETA_DBSyncModelObject

@property (nonatomic, readwrite, strong) NSString* name;
@property (nonatomic, readwrite, strong) NSDate* modified;
@property (nonatomic, readwrite, assign) ETA_ShoppingList_Access access;
@property (nonatomic, readwrite, assign) ETA_ShoppingList_Type type;
@property (nonatomic, readwrite, strong) NSDictionary* meta;



+ (instancetype) listWithUUID:(NSString*)uuid name:(NSString*)name modifiedDate:(NSDate*)modified access:(ETA_ShoppingList_Access)access type:(ETA_ShoppingList_Type)type;
// uuid and name are required
// if modified is nil, current date is used
+ (instancetype) shoppingListWithUUID:(NSString*)uuid name:(NSString*)name modifiedDate:(NSDate*)modified access:(ETA_ShoppingList_Access)access;
+ (instancetype) wishListWithUUID:(NSString*)uuid name:(NSString*)name modifiedDate:(NSDate*)modified access:(ETA_ShoppingList_Access)access;

- (NSString*)accessString;

@end
