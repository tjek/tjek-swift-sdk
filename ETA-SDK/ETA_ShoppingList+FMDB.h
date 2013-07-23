//
//  ETA_ShoppingList+FMDB.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ShoppingList.h"


@class FMResultSet, FMDatabase;
@interface ETA_ShoppingList (FMDB)

// create the shopping list table with the specified name in the db
+ (BOOL) createTable:(NSString*)tableName inDB:(FMDatabase*)db;

// empty the table specified with the name in the db
+ (BOOL) clearTable:(NSString*)tableName inDB:(FMDatabase*)db;

#pragma mark - Converters

// convert a resultSet into a shopping list
+ (ETA_ShoppingList*) shoppingListFromResultSet:(FMResultSet*)res;

// get the parameters & values of the list in a form that can be added to the DB
- (NSDictionary*) dbParameterDictionary;



#pragma mark - Getters

// get all the shopping lists
+ (NSArray*) getAllListsFromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get the shopping list with the specified ID
+ (ETA_ShoppingList*) getListWithID:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get the shopping list with the specified human-readable name
+ (ETA_ShoppingList*) getListWithName:(NSString*)listName fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// get the lists that have the specified sync state
+ (NSArray*) getAllListsWithSyncState:(ETA_DBSyncState)syncState fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

// does the specified shopping list id exist in the table/db?
+ (BOOL) listExistsWithID:(NSString*)listID inTable:(NSString*)tableName inDB:(FMDatabase*)db;


#pragma mark - Setters

// replace or insert a list in the db with 'list'. returns success or failure.
+ (BOOL) insertOrReplaceList:(ETA_ShoppingList*)list intoTable:(NSString*)tableName inDB:(FMDatabase*)db;

// remove the list from the table/db.  returns success or failure.
+ (BOOL) deleteList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;

@end
