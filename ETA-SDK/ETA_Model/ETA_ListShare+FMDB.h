//
//  ETA_ShoppingList+FMDB.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ListShare.h"

@class FMResultSet, FMDatabase;

// This category adds a lot of handy methods for talking to an FMDB database.
// It contains the table definition for an object of this type.

@interface ETA_ListShare (FMDB)

// create the share table with the specified name in the db
+ (BOOL) createTable:(NSString*)tableName inDB:(FMDatabase*)db;

// empty the table specified with the name in the db
+ (BOOL) clearTable:(NSString*)tableName inDB:(FMDatabase*)db;

#pragma mark - Converters

// convert a resultSet into a share
+ (ETA_ListShare*) listShareFromResultSet:(FMResultSet*)res;

// get the parameters & values of the list in a form that can be added to the DB
- (NSDictionary*) dbParameterDictionary;



#pragma mark Getters

+ (ETA_ListShare*) getShareForUserEmail:(NSString*)userEmail inList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;
+ (NSArray*) getAllSharesForList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;
+ (NSArray*) getAllSharesWithSyncStates:(NSArray*)syncStates andUserID:(id)userID fromTable:(NSString*)tableName inDB:(FMDatabase*)db;


+ (BOOL) insertOrReplaceShare:(ETA_ListShare*)share intoTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error;
+ (BOOL) deleteShare:(ETA_ListShare*)share fromTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error;


@end
