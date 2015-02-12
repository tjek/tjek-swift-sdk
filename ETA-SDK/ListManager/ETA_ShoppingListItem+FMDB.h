//
//  ETA_ShoppingListItem+FMDB.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/22/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ShoppingListItem.h"

@class FMResultSet, FMDatabase;

extern NSString* const kETA_ListItem_DBQuery_UserID;
extern NSString* const kETA_ListItem_DBQuery_SyncState;
extern NSString* const kETA_ListItem_DBQuery_ListID;
extern NSString* const kETA_ListItem_DBQuery_PrevItemID;
extern NSString* const kETA_ListItem_DBQuery_OfferID;

// This category adds a lot of handy methods for talking to an FMDB database.
// It contains the table definition for an object of this type.

@interface ETA_ShoppingListItem (FMDB)

// create the shopping list items table with the specified name in the db
+ (BOOL) createTable:(NSString*)tableName inDB:(FMDatabase*)db;

// empty the table specified with the name in the db
+ (BOOL) clearTable:(NSString*)tableName inDB:(FMDatabase*)db;

#pragma mark - Converters

// convert a resultSet into a shopping list item
+ (ETA_ShoppingListItem*) shoppingListItemFromResultSet:(FMResultSet*)res;

// get the parameters & values of the item in a form that can be added to the DB
- (NSDictionary*) dbParameterDictionary;



#pragma mark - Getters


// get the shopping list item with the specified ID
+ (ETA_ShoppingListItem*) getItemWithID:(NSString*)itemID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

+ (NSArray*) getAllItemsWhere:(NSDictionary*)whereKeyValues fromTable:(NSString*)tableName inDB:(FMDatabase*)db;


#pragma mark - Setters

// replace or insert an item in the db with 'list'. returns success or failure.
+ (BOOL) insertOrReplaceItem:(ETA_ShoppingListItem*)item intoTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error;

// remove the item from the table/db.  returns success or failure.
+ (BOOL) deleteItem:(NSString*)itemID fromTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error;


@end
