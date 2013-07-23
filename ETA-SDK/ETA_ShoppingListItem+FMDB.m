//
//  ETA_ShoppingListItem+FMDB.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/22/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ShoppingListItem+FMDB.h"

#import "FMDatabase.h"
#import "FMResultSet.h"

NSString* const kSLI_ID         = @"id";
NSString* const kSLI_ERN        = @"ern";
NSString* const kSLI_MODIFIED   = @"modified";
NSString* const kSLI_DESCRIPTION = @"description";
NSString* const kSLI_COUNT      = @"count";
NSString* const kSLI_TICK       = @"tick";
NSString* const kSLI_OFFER_ID   = @"offer_id";
NSString* const kSLI_CREATOR    = @"creator";
NSString* const kSLI_SHOPPING_LIST_ID = @"shopping_list_id";
NSString* const kSLI_STATE      = @"state";

@implementation ETA_ShoppingListItem (FMDB)

+ (NSArray*) dbFieldNames
{
    return @[kSLI_ID,
             kSLI_ERN,
             kSLI_MODIFIED,
             kSLI_DESCRIPTION,
             kSLI_COUNT,
             kSLI_TICK,
             kSLI_OFFER_ID,
             kSLI_CREATOR,
             kSLI_SHOPPING_LIST_ID,
             kSLI_STATE,
             ];
}

+ (NSDictionary *)JSONKeyPathsByDBFieldName
{
    return @{kSLI_ID: @"id",
             kSLI_ERN: @"ern",
             kSLI_MODIFIED: @"modified",
             kSLI_DESCRIPTION: @"description",
             kSLI_COUNT: @"count",
             kSLI_TICK: @"tick",
             kSLI_OFFER_ID: @"offer_id",
             kSLI_CREATOR: @"creator",
             kSLI_SHOPPING_LIST_ID: @"shopping_list_id",
             kSLI_STATE: @"state",
             };
}

#pragma mark - Converters

+ (ETA_ShoppingListItem*) shoppingListItemFromResultSet:(FMResultSet*)res
{
    if (!res)
        return nil;
    
    NSDictionary* resDict = [res resultDictionary];
    
    NSMutableDictionary* jsonDict = [NSMutableDictionary dictionaryWithCapacity:resDict.count];
    
    [jsonDict setValue:[res stringForColumn:kSLI_ID] forKey:@"id"];
    [jsonDict setValue:[res stringForColumn:kSLI_ERN] forKey:@"ern"];
    [jsonDict setValue:[res stringForColumn:kSLI_MODIFIED] forKey:@"modified"];
    [jsonDict setValue:[res stringForColumn:kSLI_DESCRIPTION] forKey:@"description"];
    [jsonDict setValue:@([res intForColumn:kSLI_COUNT]) forKey:@"count"];
    [jsonDict setValue:@([res intForColumn:kSLI_TICK]) forKey:@"tick"];
    [jsonDict setValue:[res stringForColumn:kSLI_OFFER_ID] forKey:@"offer_id"];
    [jsonDict setValue:[res stringForColumn:kSLI_CREATOR] forKey:@"creator"];
    [jsonDict setValue:[res stringForColumn:kSLI_SHOPPING_LIST_ID] forKey:@"shopping_list_id"];
    
    ETA_ShoppingListItem* item = [ETA_ShoppingListItem objectFromJSONDictionary:jsonDict];
    // state is not part of the JSON parsing, so set manually
    item.state = [res longForColumn:kSLI_STATE];
    
    return item;
}

- (NSDictionary*) dbParameterDictionary
{
    // get the json-ified values for the item
    NSMutableDictionary* jsonDict = [[self JSONDictionary] mutableCopy];
    jsonDict[@"state"] = @(self.state);
    jsonDict[@"tick"] = @(self.tick); // because server's json needs to be in string form 'true' / 'false'
    jsonDict[@"offer_id"] = (self.offerID) ?: NSNull.null; // because server can't handle json with NULL or nil
    
    NSDictionary* jsonKeysByFieldNames = [[self class] JSONKeyPathsByDBFieldName];
    
    // map the json keys -> db keys
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithCapacity:jsonKeysByFieldNames.count];
    [jsonKeysByFieldNames enumerateKeysAndObjectsUsingBlock:^(NSString* fieldName, NSString* JSONKeyPath, BOOL *stop) {
        id val = nil;
        if (JSONKeyPath)
            val = [jsonDict valueForKeyPath:JSONKeyPath];
        
        if (!val)
            val = NSNull.null;
        
        params[fieldName] = val;
    }];
    
    return params;
}

#pragma mark - table operations

+ (BOOL) createTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSString* fieldsStr = [@[kSLI_ID, @"text primary key,",
                             kSLI_ERN, @"text not null,",
                             kSLI_MODIFIED, @"text not null,",
                             kSLI_DESCRIPTION, @"text,",
                             kSLI_COUNT, @"integer not null,",
                             kSLI_TICK, @"integer not null,",
                             kSLI_OFFER_ID, @"text,",
                             kSLI_CREATOR, @"text not null,",
                             kSLI_SHOPPING_LIST_ID, @"text not null,",
                             kSLI_STATE, @"integer not null",
                             ] componentsJoinedByString:@" "];
    
    NSString* queryStr = [NSString stringWithFormat:@"create table if not exists %@(%@);", tableName, fieldsStr];
    BOOL success = [db executeUpdate:queryStr];
    if (!success)
        DLog(@"Unable to create table '%@': %@", tableName, db.lastError);
    
    return success;
}

+ (BOOL) clearTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSString* queryStr = [NSString stringWithFormat:@"DELETE FROM %@;", tableName];
    BOOL success = [db executeUpdate:queryStr];
    if (!success)
        DLog(@"Unable to empty table '%@': %@", tableName, db.lastError);
    
    return success;
}


#pragma mark - Getters

+ (NSArray*) getAllItemsFromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@", tableName];
    
    FMResultSet* s = [db executeQuery:query];
    NSMutableArray* items = [NSMutableArray array];
    while ([s next])
    {
        ETA_ShoppingListItem* item = [self shoppingListItemFromResultSet:s];
        if (item)
            [items addObject:item];
    }
    [s close];
    return items;
}

+ (ETA_ShoppingListItem*) getItemWithID:(NSString*)itemID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!itemID || !tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?", tableName, kSLI_ID];
    
    FMResultSet* s = [db executeQuery:query, itemID];
    ETA_ShoppingListItem* res = nil;
    if ([s next])
        res = [self shoppingListItemFromResultSet:s];
    [s close];
    
    return res;
}

+ (NSArray*) getAllItemsForShoppingList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!listID)
        return [self getAllItemsFromTable:tableName inDB:db];
    
    if (!tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=:listID", tableName, kSLI_SHOPPING_LIST_ID];
    NSMutableDictionary* params = [@{@"listID":listID} mutableCopy];
    
    
    if (filter != ETA_ShoppingListItemFilter_All)
    {
        query = [query stringByAppendingFormat:@" AND %@=:ticked", kSLI_TICK];
        params[@"ticked"] = (ETA_ShoppingListItemFilter_Ticked) ? @(1) : @(0);
    }
    
    
    FMResultSet* s = [db executeQuery:query withParameterDictionary:params];
    NSMutableArray* items = [NSMutableArray array];
    while ([s next])
    {
        ETA_ShoppingListItem* item = [self shoppingListItemFromResultSet:s];
        if (item)
            [items addObject:item];
    }
    [s close];
    return items;
}

+ (NSArray*) getAllItemsWithSyncState:(ETA_DBSyncState)syncState fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?", tableName, kSLI_STATE];
    
    FMResultSet* s = [db executeQuery:query, @(syncState)];
    NSMutableArray* items = [NSMutableArray array];
    while ([s next])
    {
        ETA_ShoppingListItem* item = [self shoppingListItemFromResultSet:s];
        if (item)
            [items addObject:item];
    }
    [s close];
    return items;

}

+ (BOOL) itemExistsWithID:(NSString*)itemID inTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!itemID || !tableName || !db)
        return NO;
    
    NSString* query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?", tableName, kSLI_ID];
    
    FMResultSet* s = [db executeQuery:query, itemID];
    BOOL res = NO;
    if ([s next])
        res = ([s intForColumnIndex:0] > 0);
    [s close];
    return res;
}


#pragma mark - Setters

// replace or insert an item in the db with 'list'. returns success or failure.
+ (BOOL) insertOrReplaceItem:(ETA_ShoppingListItem*)item intoTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSDictionary* params = [item dbParameterDictionary];
    
    NSString* query = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ VALUES (:%@)", tableName, [[self dbFieldNames] componentsJoinedByString:@", :"]];
    
    BOOL success = [db executeUpdate:query withParameterDictionary:params];
    if (!success)
        DLog(@"Unable to Insert/Replace Item %@: %@", params, db.lastError);
    
    return success;
}

+ (BOOL) deleteItem:(NSString*)itemID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSString* query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?", tableName, kSLI_ID];
    
    BOOL success = [db executeUpdate:query, itemID];
    if (!success)
        DLog(@"Unable to Delete Item %@: %@", itemID, db.lastError);
    
    return success;
}

+ (BOOL) deleteAllItemsForShoppingList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSString* query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=:listID", tableName, kSLI_SHOPPING_LIST_ID];
    NSMutableDictionary* params = [@{@"listID":listID} mutableCopy];
    
    if (filter != ETA_ShoppingListItemFilter_All)
    {
        query = [query stringByAppendingFormat:@" AND %@=:ticked", kSLI_TICK];
        params[@"ticked"] = (ETA_ShoppingListItemFilter_Ticked) ? @(1) : @(0);
    }
    
    BOOL success = [db executeUpdate:query withParameterDictionary:params];
    if (!success)
        DLog(@"Unable to Delete Items in Shopping List %@: %@", listID, db.lastError);
    
    return success;
}

@end
