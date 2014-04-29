//
//  ETA_ShoppingList+FMDB.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ShoppingList+FMDB.h"
#import "ETA_Log.h"

#import "ETA_ListShare+FMDB.h"

#import "FMDatabase.h"
#import "FMResultSet.h"

NSString* const kSL_ID          = @"id";
NSString* const kSL_ERN         = @"ern";
NSString* const kSL_MODIFIED    = @"modified";
NSString* const kSL_NAME        = @"name";
NSString* const kSL_ACCESS      = @"access";
NSString* const kSL_STATE       = @"state";
NSString* const kSL_TYPE        = @"type";
NSString* const kSL_META        = @"meta";
NSString* const kSL_USERID        = @"userID";

@implementation ETA_ShoppingList (FMDB)

+ (NSArray*) dbFieldNames
{
    return @[kSL_ID,
             kSL_MODIFIED,
             kSL_ERN,
             kSL_NAME,
             kSL_ACCESS,
             kSL_STATE,
             kSL_TYPE,
             kSL_META,
             kSL_USERID,
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
             kSL_TYPE: @"type",
             kSL_META: @"meta",
             kSL_USERID: @"syncUserID",
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
    
    NSString* metaJSONString = [res stringForColumn:kSL_META];
    if (metaJSONString)
    {
        id metaDict = [NSJSONSerialization JSONObjectWithData:[metaJSONString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if (metaDict)
            jsonDict[@"meta"] = metaDict;
    }
    
    ETA_ShoppingList* list = [ETA_ShoppingList objectFromJSONDictionary:jsonDict];
    // state & sync user is not part of the JSON parsing, so set manually
    list.state = [res longForColumn:kSL_STATE];
    list.syncUserID = [res stringForColumn:kSL_USERID];
    
    // type is saved as enum, not JSON string
    list.type = [res longForColumn:kSL_TYPE];
    
    return list;
}

- (NSDictionary*) dbParameterDictionary
{
    // get the json-ified values for the shopping list
    NSMutableDictionary* jsonDict = [[self JSONDictionary] mutableCopy];
    jsonDict[@"state"] = @(self.state);
    jsonDict[@"syncUserID"] = self.syncUserID ?: NSNull.null;
    jsonDict[@"type"] = @(self.type);
    
    // convert meta dict into string
    if (self.meta)
    {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.meta options:0 error:nil];
        [jsonDict setValue:jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : nil forKey:@"meta"];
    }
    
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
                              kSL_TYPE, @"integer not null DEFAULT 0,",
                              kSL_META, @"text,",
                              kSL_USERID, @"text",
                              ] componentsJoinedByString:@" "];
    
    
    NSString* queryStr = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);", tableName, fieldsStr];
    BOOL success = [db executeUpdate:queryStr];
    if (!success)
    {
        ETASDKLogError(@"[ETA_ShoppingList+FMDB] Unable to create table '%@': %@", tableName, db.lastError);
    }
    return success;
}

+ (BOOL) clearTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSString* queryStr = [NSString stringWithFormat:@"DELETE FROM %@;", tableName];
    BOOL success = [db executeUpdate:queryStr];
    if (!success)
        ETASDKLogError(@"[ETA_ShoppingList+FMDB] Unable to empty table '%@': %@", tableName, db.lastError);
    
    return success;
}

#pragma mark - Getters

+ (NSArray*) getAllListsWithSyncStates:(NSArray*)syncStates andUserID:(id)userID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!tableName || !db)
        return nil;
    
    NSMutableDictionary* params = [NSMutableDictionary new];
    
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@", tableName];
    
    NSMutableArray* WHERE = [NSMutableArray array];
    
    if ([userID isEqual:NSNull.null])
    {
        [WHERE addObject:[NSString stringWithFormat:@"%@ IS NULL", kSL_USERID]];
    }
    else if (userID)
    {
        [WHERE addObject:[NSString stringWithFormat:@"%@ == :userID", kSL_USERID]];
        params[@"userID"] = userID;
    }
    
    if (syncStates.count)
    {
        [WHERE addObject:[NSString stringWithFormat:@"%@ IN (%@)", kSL_STATE, [syncStates componentsJoinedByString:@","]]];
    }
    
    
    if (WHERE.count)
        query = [query stringByAppendingString:[NSString stringWithFormat:@" WHERE %@", [WHERE componentsJoinedByString:@" AND "]]];
    
    
    
    FMResultSet* s = [db executeQuery:query withParameterDictionary:params];
    NSMutableArray* lists = [NSMutableArray array];
    while ([s next])
    {
        ETA_ShoppingList* list = [self shoppingListFromResultSet:s];
        if (list) {
            [lists addObject:list];
        }
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


#pragma mark - Setters

// replace or insert a list in the db with 'list'
+ (BOOL) insertOrReplaceList:(ETA_ShoppingList*)list intoTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error
{
    NSDictionary* params = [list dbParameterDictionary];
    
    NSString* query = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ VALUES (:%@)", tableName, [[self dbFieldNames] componentsJoinedByString:@", :"]];
    
    BOOL success = [db executeUpdate:query withParameterDictionary:params];
    if (!success) {
        if (error)
            *error = db.lastError;
        ETASDKLogError(@"[ETA_ShoppingList+FMDB] Unable to Insert/Replace List %@: %@", params, db.lastError);
    }
    return success;
}

// remove the list from the table/db
+ (BOOL) deleteList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error
{
    NSString* query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?", tableName, kSL_ID];
    
    BOOL success = [db executeUpdate:query, listID];
    if (!success) {
        if (error)
            *error = db.lastError;
        ETASDKLogError(@"[ETA_ShoppingList+FMDB] Unable to Delete List %@: %@", listID, db.lastError);
    }
    return success;
}

@end
