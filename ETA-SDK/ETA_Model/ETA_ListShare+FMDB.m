//
//  ETA_ShoppingList+FMDB.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ListShare+FMDB.h"

#import "FMDatabase.h"
#import "FMResultSet.h"

NSString* const kLS_LIST_ID        = @"listUUID";
NSString* const kLS_USERNAME      = @"userName";
NSString* const kLS_USEREMAIL      = @"userEmail";
NSString* const kLS_ACCESS      = @"access";
NSString* const kLS_ACCEPTED      = @"accepted";
NSString* const kLS_ACCEPTURL        = @"acceptURL";
NSString* const kLS_STATE       = @"state";
NSString* const kLS_USERID        = @"userID";


@implementation ETA_ListShare (FMDB)

+ (NSArray*) dbFieldNames
{
    return @[kLS_LIST_ID,
             kLS_USERNAME,
             kLS_USEREMAIL,
             kLS_ACCESS,
             kLS_ACCEPTED,
             kLS_ACCEPTURL,
             kLS_STATE,
             kLS_USERID,
             ];
}

+ (NSDictionary *)JSONKeyPathsByDBFieldName
{
    return @{
             kLS_LIST_ID: @"listUUID",
             kLS_USERNAME: @"user.name",
             kLS_USEREMAIL: @"user.email",
             kLS_ACCESS: @"access",
             kLS_ACCEPTED: @"accepted",
             kLS_ACCEPTURL: @"acceptURL",
             kLS_STATE: @"state",
             kLS_USERID: @"syncUserID",
             };
}


+ (ETA_ListShare*) listShareFromResultSet:(FMResultSet*)res
{
    if (!res)
        return nil;
    
    NSMutableDictionary* jsonDict = [NSMutableDictionary dictionary];

    [jsonDict setValue:[res stringForColumn:kLS_LIST_ID] forKey:@"listUUID"];
    [jsonDict setValue:[res stringForColumn:kLS_ACCESS] forKey:@"access"];
    [jsonDict setValue:@([res intForColumn:kLS_ACCEPTED]) forKey:@"accepted"];
    [jsonDict setValue:[res stringForColumn:kLS_ACCEPTURL] forKey:@"acceptURL"];
    
    NSMutableDictionary* userDict = [NSMutableDictionary dictionary];
    [userDict setValue:[res stringForColumn:kLS_USERNAME] forKey:@"name"];
    [userDict setValue:[res stringForColumn:kLS_USEREMAIL] forKey:@"email"];
    [jsonDict setValue:userDict forKey:@"user"];
    
    ETA_ListShare* share = [ETA_ListShare objectFromJSONDictionary:jsonDict];

    // state & sync user is not part of the JSON parsing, so set manually
    share.state = [res longForColumn:kLS_STATE];
    share.syncUserID = [res stringForColumn:kLS_USERID];
    
    return share;
}

- (NSDictionary*) dbParameterDictionary
{
    // get the json-ified values for the share
    NSMutableDictionary* jsonDict = [[self JSONDictionary] mutableCopy];
    
    jsonDict[@"state"] = @(self.state);
    jsonDict[@"syncUserID"] = self.syncUserID ?: NSNull.null;
    
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
    NSString* fieldsStr = [@[ kLS_LIST_ID, @"text not null,",
                              kLS_USEREMAIL, @"text not null,",
                              kLS_USERNAME, @"text not null,",
                              kLS_ACCESS, @"text not null,",
                              kLS_ACCEPTED, @"integer not null,",
                              kLS_ACCEPTURL, @"text,",
                              kLS_STATE, @"integer not null,",
                              kLS_USERID, @"text",
                              ] componentsJoinedByString:@" "];
    
    NSString* queryStr = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);", tableName, fieldsStr];
    BOOL success = [db executeUpdate:queryStr];
    if (!success)
    {
        NSLog(@"[ETA_ListShare+FMDB] Unable to create table '%@': %@", tableName, db.lastError);
    }
    return success;
}

+ (BOOL) clearTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    NSString* queryStr = [NSString stringWithFormat:@"DELETE FROM %@;", tableName];
    BOOL success = [db executeUpdate:queryStr];
    if (!success)
        NSLog(@"[ETA_ListShare+FMDB] Unable to empty table '%@': %@", tableName, db.lastError);
    
    return success;
}

#pragma mark - Getters

+ (ETA_ListShare*) getShareForUserEmail:(NSString*)userEmail inList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!userEmail || !listID || !tableName || !db)
        return nil;
    
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND %@=? AND %@ NOT IN (%@)", tableName, kLS_USEREMAIL, kLS_LIST_ID,
                       kLS_STATE, [@[@(ETA_DBSyncState_ToBeDeleted), @(ETA_DBSyncState_Deleting), @(ETA_DBSyncState_Deleted)] componentsJoinedByString:@","]];
    
    FMResultSet* s = [db executeQuery:query, userEmail, listID];
    ETA_ListShare* res = nil;
    if ([s next])
        res = [self listShareFromResultSet:s];
    [s close];
    
    return res;
}
+ (NSArray*) getAllSharesForList:(NSString*)listID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!listID || !tableName || !db)
        return nil;
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND %@ NOT IN (%@)", tableName, kLS_LIST_ID,
                       kLS_STATE, [@[@(ETA_DBSyncState_ToBeDeleted), @(ETA_DBSyncState_Deleting), @(ETA_DBSyncState_Deleted)] componentsJoinedByString:@","]];
    
    FMResultSet* s = [db executeQuery:query, listID];
    
    NSMutableArray* shares = [NSMutableArray array];
    while ([s next])
    {
        ETA_ListShare* share = [self listShareFromResultSet:s];
        if (share)
            [shares addObject:share];
    }
    [s close];
    return shares;
}

+ (NSArray*) getAllSharesWithSyncStates:(NSArray*)syncStates andUserID:(id)userID fromTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!tableName || !db)
        return nil;
    
    NSMutableDictionary* params = [NSMutableDictionary new];
    
    
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@", tableName];
    
    NSMutableArray* WHERE = [NSMutableArray array];
    
    if ([userID isEqual:NSNull.null])
    {
        [WHERE addObject:[NSString stringWithFormat:@"%@ IS NULL", kLS_USERID]];
    }
    else if (userID)
    {
        [WHERE addObject:[NSString stringWithFormat:@"%@ == :userID", kLS_USERID]];
        params[@"userID"] = userID;
    }
    
    if (syncStates.count)
    {
        [WHERE addObject:[NSString stringWithFormat:@"%@ IN (%@)", kLS_STATE, [syncStates componentsJoinedByString:@","]]];
    }
    
    
    if (WHERE.count)
        query = [query stringByAppendingString:[NSString stringWithFormat:@" WHERE %@", [WHERE componentsJoinedByString:@" AND "]]];
    
    
    
    FMResultSet* s = [db executeQuery:query withParameterDictionary:params];
    NSMutableArray* shares = [NSMutableArray array];
    while ([s next])
    {
        ETA_ListShare* share = [self listShareFromResultSet:s];
        if (share) {
            [shares addObject:share];
        }
    }
    [s close];
    return shares;
}




+ (BOOL) shareExistsForUserEmail:(NSString*)userEmail inList:(NSString*)listID inTable:(NSString*)tableName inDB:(FMDatabase*)db
{
    if (!userEmail || !listID || !tableName || !db)
        return NO;
    
    NSString* query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND %@=?", tableName, kLS_USEREMAIL, kLS_LIST_ID];
    
    FMResultSet* s = [db executeQuery:query, userEmail, listID];
    BOOL res = NO;
    if ([s next])
        res = ([s intForColumnIndex:0] > 0);
    [s close];
    return res;
}



#pragma mark - Setters

// replace or insert a list in the db with 'share'
+ (BOOL) insertOrReplaceShare:(ETA_ListShare*)share intoTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error
{
    // first try to delete the existing share
    [self deleteShare:share fromTable:tableName inDB:db error:nil];
    
    NSDictionary* params = [share dbParameterDictionary];
    NSArray* fields = [self dbFieldNames];
    NSString* query = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (:%@)", tableName,
                       [fields componentsJoinedByString:@","], [fields componentsJoinedByString:@", :"]];
    
    
    BOOL success = [db executeUpdate:query withParameterDictionary:params];
    if (!success) {
        if (error)
            *error = db.lastError;
        NSLog(@"[ETA_ListShare+FMDB] Unable to Insert/Replace Share %@: %@", params, db.lastError);
    }
    return success;
}

// remove the share from the table/db
+ (BOOL) deleteShare:(ETA_ListShare*)share fromTable:(NSString*)tableName inDB:(FMDatabase*)db error:(NSError * __autoreleasing *)error
{
    NSString* query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=? AND %@=?", tableName, kLS_USEREMAIL, kLS_LIST_ID];
    
    BOOL success = [db executeUpdate:query, share.userEmail, share.listUUID];
    if (!success) {
        if (error)
            *error = db.lastError;
        NSLog(@"[ETA_ListShare+FMDB] Unable to Delete Share %@-%@: %@", share.listUUID, share.userEmail, db.lastError);
    }
    return success;
}

@end
