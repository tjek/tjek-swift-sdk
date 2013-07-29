//
//  ETA_ShoppingList+FMDB.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ShoppingList+FMDB.h"

#import "FMDatabase.h"
#import "FMResultSet.h"

NSString* const kSL_ID          = @"id";
NSString* const kSL_ERN         = @"ern";
NSString* const kSL_MODIFIED    = @"modified";
NSString* const kSL_NAME        = @"name";
NSString* const kSL_ACCESS      = @"access";
NSString* const kSL_STATE       = @"state";
NSString* const kSL_OWNER_USER  = @"owner_user";
NSString* const kSL_OWNER_ACCESS = @"owner_access";
NSString* const kSL_OWNER_ACCEPTED = @"owner_accepted";

@implementation ETA_ShoppingList (FMDB)


+ (NSArray*) dbFieldNames
{
    return @[kSL_ID,
             kSL_MODIFIED,
             kSL_ERN,
             kSL_NAME,
             kSL_ACCESS,
             kSL_STATE,
             kSL_OWNER_USER,
             kSL_OWNER_ACCESS,
             kSL_OWNER_ACCEPTED,
             ];
}

+ (NSDictionary *)JSONKeyPathsByDBFieldName
{
    return @{
             kSL_ID: @"id",
             kSL_MODIFIED: @"modified",
             kSL_ERN: @"ern",
             kSL_NAME: @"name",
             kSL_ACCESS: @"access",
             kSL_STATE: @"state",
             kSL_OWNER_USER: @"owner.user",
             kSL_OWNER_ACCESS: @"owner.access",
             kSL_OWNER_ACCEPTED: @"owner.accepted",
             };
}


+ (ETA_ShoppingList*) shoppingListFromResultSet:(FMResultSet*)res
{
    if (!res)
        return nil;
    
    NSDictionary* resDict = [res resultDictionary];
    
    NSMutableDictionary* jsonDict = [NSMutableDictionary dictionaryWithCapacity:resDict.count];
    
    
    [jsonDict setValue:[res stringForColumn:kSL_ID] forKey:@"id"];
    [jsonDict setValue:[res stringForColumn:kSL_MODIFIED] forKey:@"modified"];
    [jsonDict setValue:[res stringForColumn:kSL_ERN] forKey:@"ern"];
    [jsonDict setValue:[res stringForColumn:kSL_NAME] forKey:@"name"];
    [jsonDict setValue:[res stringForColumn:kSL_ACCESS] forKey:@"access"];

    NSMutableDictionary* owner = [@{} mutableCopy];
    [owner setValue:[res stringForColumn:kSL_OWNER_USER] forKey:@"user"];
    [owner setValue:[res stringForColumn:kSL_OWNER_ACCESS] forKey:@"access"];
    [owner setValue:@([res intForColumn:kSL_OWNER_ACCEPTED]) forKey:@"accepted"];
    jsonDict[@"owner"] = owner;
    
    
    ETA_ShoppingList* list = [ETA_ShoppingList objectFromJSONDictionary:jsonDict];
    // state is not part of the JSON parsing, so set manually
    list.state = [res longForColumn:kSL_STATE];
    
    return list;
}

- (NSDictionary*) dbParameterDictionary
{
    // get the json-ified values for the shopping list
    NSMutableDictionary* jsonDict = [[self JSONDictionary] mutableCopy];
    jsonDict[@"state"] = @(self.state);
    
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
    NSString* fieldsStr = [@[ kSL_ID, @"text primary key,",
                              kSL_MODIFIED, @"text not null,",
                              kSL_ERN, @"text,",
                              kSL_NAME, @"text not null,",
                              kSL_ACCESS, @"text not null,",
                              kSL_STATE, @"integer not null,",
                              kSL_OWNER_USER, @"text,",
                              kSL_OWNER_ACCESS, @"text,",
                              kSL_OWNER_ACCEPTED, @"integer"
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

// get all the shopping lists
+ (NSArray*) getAllListsFromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@", tableName];
    
    FMResultSet* s = [db executeQuery:query];
    NSMutableArray* lists = [NSMutableArray array];
    while ([s next])
    {
        ETA_ShoppingList* list = [self shoppingListFromResultSet:s];
        if (list)
            [lists addObject:list];
    }
    [s close];
    return lists;
}

// get the shopping list with the specified ID
+ (ETA_ShoppingList*) getListWithID:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!listID || !tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?", tableName, kSL_ID];
    
    FMResultSet* s = [db executeQuery:query, listID];
    ETA_ShoppingList* res = nil;
    if ([s next])
        res = [self shoppingListFromResultSet:s];
    [s close];
    
    return res;
}

// get the shopping list with the specified human-readable name
+ (ETA_ShoppingList*) getListWithName:(NSString*)listName fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!listName || !tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?", tableName, kSL_NAME];
    
    FMResultSet* s = [db executeQuery:query, listName];
    ETA_ShoppingList* res = nil;
    if ([s next])
        res = [self shoppingListFromResultSet:s];
    [s close];
    
    return res;
}

// does the specified shopping list id exist in the table/db?
+ (BOOL) listExistsWithID:(NSString*)listID inTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!listID || !tableName || !db)
        return NO;
    
    NSString* query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?", tableName, kSL_ID];
    
    FMResultSet* s = [db executeQuery:query, listID];
    BOOL res = NO;
    if ([s next])
        res = ([s intForColumnIndex:0] > 0);
    [s close];
    return res;
}


+ (NSArray*) getAllListsWithSyncState:(ETA_DBSyncState)syncState fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?", tableName, kSL_STATE];
    
    FMResultSet* s = [db executeQuery:query, @(syncState)];
    NSMutableArray* lists = [NSMutableArray array];
    while ([s next])
    {
        ETA_ShoppingList* list = [self shoppingListFromResultSet:s];
        if (list)
            [lists addObject:list];
    }
    [s close];
    return lists;
}



#pragma mark - Setters

// replace or insert a list in the db with 'list'
+ (BOOL) insertOrReplaceList:(ETA_ShoppingList*)list intoTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSDictionary* params = [list dbParameterDictionary];
    
    NSString* query = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ VALUES (:%@)", tableName, [[self dbFieldNames] componentsJoinedByString:@", :"]];
    
    BOOL success = [db executeUpdate:query withParameterDictionary:params];
    if (!success)
        DLog(@"Unable to Insert/Replace List %@: %@", params, db.lastError);

    return success;
}

// remove the list from the table/db
+ (BOOL) deleteList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSString* query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?", tableName, kSL_ID];
    
    BOOL success = [db executeUpdate:query, listID];
    if (!success)
        DLog(@"Unable to Delete List %@: %@", listID, db.lastError);
    
    return success;
}

@end
