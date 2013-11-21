//
//  ETA_ShoppingListItem+FMDB.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/22/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ShoppingListItem.h"

#import "ETA_ShoppingListManager.h"

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





// deprecated

// syncStates, userID, listID and prevItemID are all optional. NSNull.null for items with no userID
+ (NSArray*) getAllItemsWithSyncStates:(NSArray*)syncStates
                                userID:(id)userID
                                listID:(NSString*)listID
                            prevItemID:(id)prevItemID
                               offerID:(NSString*)offerID
                             fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get all the shopping list items
+ (NSArray*) getAllItemsFromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get the shopping list item with the specified offer ID from within the specified list
+ (ETA_ShoppingListItem*) getItemWithOfferID:(NSString*)offerID inList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get the shopping list item with the specified previous item ID
+ (ETA_ShoppingListItem*) getItemWithPrevItemID:(NSString*)prevItemID inList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get the items that are in the specified shopping list
+ (NSArray*) getAllItemsForShoppingList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get the items that have the specified sync state
+ (NSArray*) getAllItemsWithSyncState:(ETA_DBSyncState)syncState fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// does the specified shopping list item id exist in the table/db?
+ (BOOL) itemExistsWithID:(NSString*)itemID inTable:(NSString*)tableName inDB:(FMDatabase*)db;

// remove all the items that are in the specified shopping list
+ (BOOL) deleteAllItemsForShoppingList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

@end
