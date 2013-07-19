//
//  ETA_ShoppingListManager.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ShoppingListManager.h"
#import "ETA.h"
#import "ETA_APIEndpoints.h"

#import "ETA_User.h"
#import "ETA_Session.h"

#import "ETA_ShoppingList.h"
#import "ETA_ShoppingListItem.h"

#import "ETA_ShoppingList+FMDB.h"

#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

NSString* const ETA_ShoppingListManager_ListsChangedNotification = @"ETA_ShoppingListManager_ListsChangedNotification";
NSString* const ETA_ShoppingListManager_ItemsChangedNotification = @"ETA_ShoppingListManager_ItemsChangedNotification";

NSTimeInterval const kETA_ShoppingListManager_DefaultPollInterval = 6.0; // secs

NSString* const kSL_TBLNAME             = @"shoppinglists";
NSString* const kSL_USERLESS_TBLNAME    = @"userless_shoppinglists";

NSString* const kSLI_TBLNAME            = @"shoppinglistitems";
NSString* const kSLI_USERLESS_TBLNAME   = @"userless_shoppinglistitems";


// expose the client to the manager
@interface ETA (ShoppingListPrivate)
//@property (nonatomic, readonly, strong) ETA_APIClient* client;
@end

//NSString* const kSL_ID          = @"id";
//NSString* const kSL_ERN         = @"ern";
//NSString* const kSL_MODIFIED    = @"modified";
//NSString* const kSL_NAME        = @"name";
//NSString* const kSL_ACCESS      = @"access";
//NSString* const kSL_STATE       = @"state";
//NSString* const kSL_OWNER_USER  = @"owner_user";
//NSString* const kSL_OWNER_ACCESS = @"owner_access";
//NSString* const kSL_OWNER_ACCEPTED = @"owner_accepted";
//
//NSString* const kSLI_ID         = @"id";
//NSString* const kSLI_ERN        = @"ern";
//NSString* const kSLI_MODIFIED   = @"modified";
//NSString* const kSLI_DESCRIPTION = @"description";
//NSString* const kSLI_COUNT      = @"count";
//NSString* const kSLI_TICK       = @"tick";
//NSString* const kSLI_OFFER_ID   = @"offer_id";
//NSString* const kSLI_CREATOR    = @"creator";
//NSString* const kSLI_SHOPPING_LIST_ID = @"shopping_list_id";
//NSString* const kSLI_STATE      = @"state";

@interface ETA_ShoppingListManager ()
@property (nonatomic, readwrite, strong) ETA* eta;
@property (nonatomic, readwrite, strong) NSString* userID; // the userID that the shopping lists were last got for

@property (nonatomic, readwrite, strong) FMDatabaseQueue *dbQ;

@property (nonatomic, readwrite, strong) NSTimer* pollingTimer;

@property (nonatomic, readwrite, assign) NSUInteger numberOfObjectsBeingSyncronized; // are we currently trying to send an item to the server?


@end

@implementation ETA_ShoppingListManager

+ (instancetype) managerWithETA:(ETA*)eta
{
    ETA_ShoppingListManager* manager = [[ETA_ShoppingListManager alloc] init];
    manager.eta = eta;
    return manager;
}

- (instancetype) init
{
    if ((self=[super init]))
    {
        NSURL* appDocsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSString* localDBPath = [[appDocsURL URLByAppendingPathComponent:@"shoppinglists.db"] path];
        
        self.dbQ = [FMDatabaseQueue databaseQueueWithPath:localDBPath];
        [self localDBCreateTables];
        
        self.pollingTimer = nil;
        self.pollInterval = kETA_ShoppingListManager_DefaultPollInterval; //secs
        
        self.numberOfObjectsBeingSyncronized = 0;
        
        self.ignoreSessionUser = NO;
    }
    return self;
}

- (void) dealloc
{
    [self stopPollingServer];
    self.eta = nil;
    self.dbQ = nil;
}



#pragma mark - User management

- (void) setEta:(ETA *)eta
{
    if (_eta == eta)
        return;
    
    
    [_eta removeObserver:self forKeyPath:@"client.session"];
    
    _eta = eta;
    
    [_eta addObserver:self forKeyPath:@"client.session" options:0 context:NULL];
    
    self.userID = [_eta attachedUserID];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"client.session"])
    {
        self.userID = [_eta attachedUserID];
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void) setUserID:(NSString *)userID
{
    if (_userID == userID || [userID isEqualToString:_userID])
        return;
    
    DLog(@"UserID changed '%@'=>'%@'", _userID, userID);
    _userID = userID;
    
    if (_userID)
        [self startPollingServer];
    else
        [self stopPollingServer];
}





#pragma mark - Local DB methods

- (void) localDBCreateTables
{
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        [ETA_ShoppingList createTable:[[self class] localDBTableName_ShoppingList:YES] inDB:db];
        [ETA_ShoppingList createTable:[[self class] localDBTableName_ShoppingList:NO] inDB:db];
        
//        [ETA_ShoppingListItem createTable:[[self class] localDBTableName_ShoppingListItem:YES] inDB:db];
//        [ETA_ShoppingListItem createTable:[[self class] localDBTableName_ShoppingListItem:NO] inDB:db];
    }];
}


#pragma mark Shopping Lists

+ (NSString*) localDBTableName_ShoppingList:(BOOL)userless
{
    return (userless) ? kSL_USERLESS_TBLNAME : kSL_TBLNAME;
}

- (ETA_ShoppingList*) localDBGetShoppingList:(NSString*)listID userID:(NSString*)userID
{
    __block ETA_ShoppingList* list = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingList:(userID==nil)];
        
        list = [ETA_ShoppingList getListWithID:listID fromTable:tblName inDB:db];
    }];
    return list;
}

- (NSArray*) localDBGetAllShoppingListsForUserID:(NSString*)userID
{
    __block NSArray* lists = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingList:(userID==nil)];
        
        lists = [ETA_ShoppingList getAllListsFromTable:tblName inDB:db];
    }];
    return lists;
}

- (BOOL) localDBContainsShoppingListWithID:(NSString*)listID userID:(NSString*)userID
{
    __block BOOL exists = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:(userID==nil)];
        
        exists = [ETA_ShoppingList listExistsWithID:listID inTable:tblName inDB:db];
    }];
    return exists;
}

- (BOOL) localDBInsertOrReplaceShoppingList:(ETA_ShoppingList*)list userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:(userID==nil)];
        
        success = [ETA_ShoppingList insertOrReplaceList:list intoTable:tblName inDB:db];
    }];
    return success;
}

- (BOOL) localDBDeleteShoppingList:(NSString*)listID userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:(userID==nil)];
        
        success = [ETA_ShoppingList deleteList:listID fromTable:tblName inDB:db];
    }];
    return success;
}


- (NSArray*) localDBGetShoppingListsWithSyncState:(ETA_DBSyncState)syncState userID:(NSString*)userID
{
    __block NSArray* lists = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:(userID==nil)];
        
        lists = [ETA_ShoppingList getListsWithSyncState:syncState fromTable:tblName inDB:db];
    }];
    return lists;
}


#pragma mark Shopping List Items

+ (NSString*) localDBTableName_ShoppingListItem:(BOOL)userless
{
    return (userless) ? kSLI_USERLESS_TBLNAME : kSLI_TBLNAME;
}

- (ETA_ShoppingListItem*) localDBGetShoppingListItem:(NSString*)itemID userID:(NSString*)userID
{
    __block ETA_ShoppingListItem* item = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:(userID==nil)];
        
        // TODO: ETA_ShoppingListItem+FMDB
//        item = [ETA_ShoppingListItem getItemWithID:itemID fromTable:tblName inDB:db];
    }];
    return item;
}

- (NSArray*) localDBGetAllShoppingListItemsForShoppingList:(NSString*)listID userID:(NSString*)userID
{
    __block NSArray* items = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:(userID==nil)];
        
        // TODO: ETA_ShoppingListItem+FMDB
//        items = [ETA_ShoppingListItem getAllItemsForShoppingList:listID fromTable:tblName inDB:db];
    }];
    return items;
}

- (BOOL) localDBContainsShoppingListItemWithID:(NSString*)itemID userID:(NSString*)userID
{
    __block BOOL exists = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:(userID==nil)];
        
        // TODO: ETA_ShoppingListItem+FMDB
//        exists = [ETA_ShoppingListItem itemExistsWithID:itemID inTable:tblName inDB:db];
    }];
    return exists;
}

- (BOOL) localDBInsertOrReplaceShoppingListItem:(ETA_ShoppingListItem*)item userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:(userID==nil)];
        
        // TODO: ETA_ShoppingListItem+FMDB
//        success = [ETA_ShoppingListItem insertOrReplaceItem:item intoTable:tblName inDB:db];
    }];
    return success;
}

- (BOOL) localDBDeleteShoppingListItem:(NSString*)itemID userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:(userID==nil)];
        
        // TODO: ETA_ShoppingListItem+FMDB
//        success = [ETA_ShoppingListItem deleteItem:itemID fromTable:tblName inDB:db];
    }];
    return success;
}


#pragma mark - Server methods

#pragma mark Shopping Lists

// go to the server and get the latest state of all the shopping lists
- (void) serverGetAllShoppingListsForUser:(NSString*)userID completion:(void (^)(NSArray* lists, NSError* error))completionHandler
{
    if (!completionHandler)
        return;
    
    //TODO: error when userID is invalid
    if (!userID)
    {
        completionHandler(nil, nil);
        return;
    }
    
    //   "/v2/users/1234/shoppinglists"
    NSString* request = [ETA_APIEndpoints apiURLForEndpointComponents:@[ ETA_User.APIEndpoint,
                                                                         userID,
                                                                         ETA_ShoppingList.APIEndpoint]];
    
    [self.eta api:request
             type:ETARequestTypeGET
       parameters:nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           NSMutableArray* lists = nil;
           if (!error)
           {
               if ([response isKindOfClass:[NSArray class]] == NO)
                   response = @[response];
               
               lists = [@[] mutableCopy];
               for (id obj in response)
               {
                   ETA_ShoppingList* shoppingList = [ETA_ShoppingList objectFromJSONDictionary:obj];
                   if (shoppingList)
                       [lists addObject:shoppingList];
               }
           }
           
           completionHandler(lists, error);
       }];
}

- (void) serverGetShoppingList:(NSString*)listID modifiedDateForUser:(NSString*)userID completion:(void (^)(NSDate* modifiedDate, NSError* error))completionHandler
{
    if (!completionHandler)
        return;
    
    //TODO: error when userID/listID is invalid
    if (!userID || !listID)
    {
        completionHandler(nil, nil);
        return;
    }
    //   "/v2/users/{userID}/shoppinglists/{listID}/modified"
    NSString* request = [ETA_APIEndpoints apiURLForEndpointComponents:@[ ETA_User.APIEndpoint,
                                                                         userID,
                                                                         ETA_ShoppingList.APIEndpoint,
                                                                         listID,
                                                                         @"modified"]];
    
    [self.eta api:request
             type:ETARequestTypeGET
       parameters:nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           NSDate* modified = nil;
           if (!error)
           {
               NSString* dateStr = [response valueForKey:@"modified"];
               if (dateStr)
                   modified = [[ETA_ShoppingList dateFormatter] dateFromString:dateStr];
           }
           
           completionHandler(modified, error);
       }];
}


- (void) serverInsertOrReplaceShoppingList:(ETA_ShoppingList *)list forUser:(NSString*)userID completion:(void (^)(ETA_ShoppingList* addedList, NSError* error))completionHandler
{
    // TODO: error when userID/list is invalid
    if (!userID || !list || !list.uuid || !list.name)
    {
        if (completionHandler)
            completionHandler(nil, nil);
        return;
    }
    
    
    NSDictionary* jsonDict = [list JSONDictionary];
    
    
    // "/v2/users/{userID}/shoppinglists/{listID}"
    NSString* request = [ETA_APIEndpoints apiURLForEndpointComponents:@[ ETA_User.APIEndpoint,
                                                                         userID,
                                                                         ETA_ShoppingList.APIEndpoint,
                                                                         list.uuid]];
    [self.eta api:request
             type:ETARequestTypePUT
       parameters:jsonDict
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           if (completionHandler)
           {
               ETA_ShoppingList* addedList = [ETA_ShoppingList objectFromJSONDictionary:response];
               
               completionHandler(addedList, error);
           }
       }];
}


#pragma mark Shopping List Items





#pragma mark - Polling

- (void) startPollingServer
{
    DLog(@"START POLLING: %d", !self.isPolling);
    if (!self.isPolling)
    {
        [self pollForServerChanges];
        self.pollingTimer = [NSTimer timerWithTimeInterval:self.pollInterval
                                                    target:self selector:@selector(pollForServerChanges)
                                                  userInfo:nil repeats:YES];
        
        // explicitly add to main run loop, in case start is being called from a bg thread
        [[NSRunLoop mainRunLoop] addTimer:self.pollingTimer forMode:NSDefaultRunLoopMode];
    }
}

- (void) stopPollingServer
{
    DLog(@"STOP POLLING: %d", self.isPolling);
    if (self.isPolling)
    {
        [self.pollingTimer invalidate];
        self.pollingTimer = nil;
    }
}

- (BOOL) isPolling
{
    return [self.pollingTimer isValid];
}

- (void) setPollInterval:(NSTimeInterval)pollInterval
{
    if (_pollInterval == pollInterval)
        return;
    
    _pollInterval = pollInterval;
    
    if (self.isPolling)
    {
        [self stopPollingServer];
        [self startPollingServer];
    }
}

// every {pollInterval} secs ask the server for all the shoppinglists
// for each list that is returned, find the differences
// if the list was modified locally more recently mark as needing
- (void) pollForServerChanges
{
    NSString* userID = self.userID;
    
    // ask for the shopping lists
    [self serverGetAllShoppingListsForUser:userID
                                completion:^(NSArray *serverLists, NSError *error) {
                                    if ([userID isEqualToString:self.userID] == NO)
                                    {
                                        DLog(@"[POLLING] ...FINISHED (for user:'%@') - user changed while polling, ignore results!", userID);
                                        return;
                                    }
                                    
                                    
                                    
                                        
                                    if (error)
                                    {
                                        DLog(@"[POLLING] ...FINISHED (for user:'%@') - failed %@", userID, error);
                                    }
                                    else
                                    {
                                        DLog(@"[POLLING] ...FINISHED (for user:'%@') - success (%d lists)", userID, serverLists.count);
                                        
                                        NSArray* localLists = [self localDBGetAllShoppingListsForUserID:userID];
                                        [self syncronizeAndNotifyChangesBetweenLocalShoppingLists:localLists andListsFromServer:serverLists];
                                    }
                                }];
    
    DLog(@"[POLLING] STARTED (for user:'%@') ...", userID);
}

// go through the lists of local and server objects, comparing them
// returns a dict of the objects that have been 'added' to the server, 'removed' from the server, or 'modified' more recently on the server
// this works with any ETA_ModelObject that has a 'modified' property
- (NSDictionary*) getDifferencesBetweenLocalObjects:(NSArray*)localObjects andServerObjects:(NSArray*)serverObjects
{
    // make maps based on the objects uuids
    NSMutableDictionary* localObjectsByUUID = [NSMutableDictionary dictionaryWithCapacity:localObjects.count];
    for (ETA_ModelObject* obj in localObjects)
        [localObjectsByUUID setValue:obj forKey:obj.uuid];
    NSMutableDictionary* serverObjectsByUUID = [NSMutableDictionary dictionaryWithCapacity:serverObjects.count];
    for (ETA_ModelObject* obj in serverObjects)
        [serverObjectsByUUID setValue:obj forKey:obj.uuid];
    
    
    NSMutableArray* removed = [localObjects mutableCopy]; // objects that were removed from the server
    NSMutableArray* added = [@[] mutableCopy]; // objects that were added to the server
    NSMutableArray* changed = [@[] mutableCopy]; // objects that have changed on the server
    
    // for each item in the server list
    [serverObjects enumerateObjectsUsingBlock:^(ETA_ModelObject* serverObj, NSUInteger idx, BOOL *stop) {
        if (!serverObj.uuid)
        {
            DLog(@"Got an object without a UUID... should not happen! %@", serverObj);
            return;
        }

        ETA_ModelObject* localObj = localObjectsByUUID[serverObj.uuid];
        
        // the object is on the server, but not locally. It needs to be added locally
        if (!localObj)
        {
            [added addObject:serverObj];
        }
        // the object exists both locally and on the server
        else
        {
            // mark as not needing to be removed
            [removed removeObject:localObj];
            
            
            // check the modified dates of the objects
            NSDate* localModifiedDate = [localObj valueForKey:@"modified"];
            NSDate* serverModifiedDate = [serverObj valueForKey:@"modified"];
            
            NSComparisonResult compare = NSOrderedSame;
            if (localModifiedDate != serverModifiedDate)
            {
                // local version has no date, while server does, so assume server is newer
                if (!localModifiedDate)
                    compare = NSOrderedAscending;
                // server has no date, but local does. odd situation, but assume local is newer
                else if (!localModifiedDate)
                    compare = NSOrderedDescending;
                // both local and server have a date - compare them
                else
                    compare = [localModifiedDate compare:serverModifiedDate];
            }
            
            // local version is older - mark as changed
            if (compare == NSOrderedAscending)
            {
                [changed addObject:serverObj];
            }
            // local version is newer - we shouldnt have polled while in the process of syncing, so do nothing
            else if (compare == NSOrderedDescending)
            {
                
            }
            // local and server are the same - do nothing
            else if (compare == NSOrderedSame)
            {
                
            }
        }
    }];
    
    NSMutableDictionary* differencesDict = [NSMutableDictionary dictionaryWithCapacity:3];
    
    if (removed.count)
        differencesDict[@"removed"] = removed;
    
    if (added.count)
        differencesDict[@"added"] = added;
    
    if (changed.count)
        differencesDict[@"modified"] = changed;
    
    return differencesDict;
}

- (void) syncronizeAndNotifyChangesBetweenLocalShoppingLists:(NSArray*)localLists andListsFromServer:(NSArray*)serverLists
{
    NSDictionary* differencesDict = [self getDifferencesBetweenLocalObjects:localLists andServerObjects:serverLists];
    
    // modify the local version
    NSString* userID = self.userID;
    
    NSArray* removed = differencesDict[@"removed"];
    NSArray* added = differencesDict[@"added"];
    NSArray* modified = differencesDict[@"modified"];
    
    [removed enumerateObjectsUsingBlock:^(ETA_ShoppingList* list, NSUInteger idx, BOOL *stop) {
        [self localDBDeleteShoppingList:list.uuid userID:userID];
    }];

    [added enumerateObjectsUsingBlock:^(ETA_ShoppingList* list, NSUInteger idx, BOOL *stop) {
        [self localDBInsertOrReplaceShoppingList:list userID:userID];
    }];
    
    [modified enumerateObjectsUsingBlock:^(ETA_ShoppingList* list, NSUInteger idx, BOOL *stop) {
        [self localDBInsertOrReplaceShoppingList:list userID:userID];
    }];
    
    
    if (differencesDict.count)
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_ShoppingListManager_ListsChangedNotification
                                                            object:self
                                                          userInfo:differencesDict];
}

- (void) syncronizeAndNotifyChangesBetweenLocalShoppingListItems:(NSArray*)localItems andListsFromServer:(NSArray*)serverItems
{
    NSDictionary* differencesDict = [self getDifferencesBetweenLocalObjects:localItems andServerObjects:serverItems];
    
    // modify the local version
    NSString* userID = self.userID;
    
    NSArray* removed = differencesDict[@"removed"];
    NSArray* added = differencesDict[@"added"];
    NSArray* modified = differencesDict[@"modified"];
    
    [removed enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* item, NSUInteger idx, BOOL *stop) {
        [self localDBDeleteShoppingListItem:item.uuid userID:userID];
    }];
    
    [added enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* item, NSUInteger idx, BOOL *stop) {
        [self localDBInsertOrReplaceShoppingListItem:item userID:userID];
    }];
    
    [modified enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* item, NSUInteger idx, BOOL *stop) {
        [self localDBInsertOrReplaceShoppingListItem:item userID:userID];
    }];
    
    
    if (differencesDict.count)
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_ShoppingListManager_ItemsChangedNotification
                                                            object:self
                                                          userInfo:differencesDict];
}



#pragma mark - User Methods



- (void) createShoppingList:(NSString*)name
{
    ETA_ShoppingList* shoppingList = [ETA_ShoppingList shoppingListWithUUID:[[self class] generateUUID]
                                                                       name:name
                                                               modifiedDate:nil
                                                                     access:ETA_ShoppingList_Access_Private];
    [self addShoppingList:shoppingList];
}

- (void) addShoppingList:(ETA_ShoppingList*)newList
{
    if (!newList || !newList.uuid || !newList.name)
    {
        //TODO: Error if invalid list
        DLog(@"Unable to add shopping list");
        return;
    }
    
    // are we adding to the local or server list?
    NSString* userID = self.userID;
    
    
    // check if a list with that ID already exists
    if ([self localDBContainsShoppingListWithID:newList.uuid userID:userID])
    {
        DLog(@"That list already exists!");
        return;
    }

    
    
    if (userID)
        self.numberOfObjectsBeingSyncronized++;
    
    
    
    // add to local DB
    // it will be marked as needing to be synced to the server
    newList.state = ETA_DBSyncState_ToBeAdded;
    [self localDBInsertOrReplaceShoppingList:newList userID:userID];
    
    // if we are not logged in then we are done. Woo!
    if (!userID)
        return;
    
    
    
    // mark as in the process of syncronizing
    newList.state = ETA_DBSyncState_Adding;
    [self localDBInsertOrReplaceShoppingList:newList userID:userID];

    
    // send request to insert to server
    [self serverInsertOrReplaceShoppingList:newList forUser:userID completion:^(ETA_ShoppingList* addedList, NSError *error) {
        
        // on success, mark as syncd
        if (!error)
        {
            DLog(@"List added to server: %@", addedList);
            // just to make sure that we didnt get nil back even though it was added successfully
            addedList = (addedList) ?: newList;
            
            // mark as in the process of syncronizing
            addedList.state = ETA_DBSyncState_Added;
            [self localDBInsertOrReplaceShoppingList:addedList userID:userID];
            
            // allow polling again
            self.numberOfObjectsBeingSyncronized--;
        }
        else
        {
            DLog(@"Couldnt Add List to server: %@", error);
            
            // mark as un-synced
            newList.state = ETA_DBSyncState_ToBeAdded;
            [self localDBInsertOrReplaceShoppingList:newList userID:userID];

            //TODO: Retry adding list
            // after a certain number of attempts, fail and put into a mode where we try to syncronize the unsynced items
        }
    }];
}


// go through all the un-synced lists and attempt to add them to the
- (BOOL) retryIncompleteSyncs:(BOOL)includeInProgressSyncs
{
    // get the lists that have not been properly synced
    
    return NO;
}



#pragma mark -


// a proxy for modifying the user shopping lists array
- (NSMutableArray*) mutableUserShoppingLists
{
    return [self mutableArrayValueForKey:@"userShoppingLists"];
}



//- (void) createShoppingList:(NSString*)name
//{
////    if (!self.userID)
////    {
////        DLog(@"Cannot create shopping list if not logged in");
////        return;
////    }
//    
//    ETA_ShoppingList* shoppingList = [ETA_ShoppingList shoppingListWithUUID:[[self class] generateUUID]
//                                                                       name:name
//                                                               modifiedDate:nil
//                                                                     access:ETA_ShoppingList_Access_Private];
//    if (!shoppingList)
//    {
//        DLog(@"Unable to create shopping list");
//        return;
//    }
//    
//    NSString* userID = self.userID;
//    
//    // mark the list as needing to be syncd
//    shoppingList.state = ETA_DBSyncState_Init;
//    
//    // add to local DB
//    [self localDBInsertOrReplaceShoppingList:shoppingList userID:userID];
//    
//    
//    shoppingList.state = ETA_DBSyncState_Synchronizing;
//    [self localDBInsertOrReplaceShoppingList:shoppingList userID:userID];
//    
//    // send request to insert to server
//    
//    // on success, mark as syncd
//    
//    
////    [self.mutableUserShoppingLists addObject:shoppingList];
////    [self saveToLocalCache];
//}

//
//- (void) insertObject:(ETA_ShoppingList *)shoppingList inMutableShoppingListsAtIndex:(NSUInteger)index
//{
//    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:index];
//    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"shoppingLists"];
//    [self.mutableShoppingLists insertObject:shoppingList atIndex:index];
//    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"shoppingLists"];
//}

//- (NSArray*)shoppingLists
//{
//    return [self.mutableShoppingLists copy];
//}

#pragma mark - Lists
- (void) getShoppingLists:(void (^)(NSArray* shoppingLists, NSError* error))completionHandler
{
    if ([self canReadShoppingLists] == NO)
        return;
    
//    NSString* request = [NSString stringWithFormat:@"%@", [ETA_APIEndpoints apiURLForEndpoint:ETA_APIEndpoints.shoppingLists]];
//
//    [self.eta api:
//             type:ETARequestTypeGET
//       parameters:nil
//       completion:^(id response, NSError *error, BOOL fromCache) {
//           
//       }];
}
- (void) createShoppingList:(NSString*)listUUID
             withProperties:(NSDictionary*)listProperties
                 completion:(void (^)(ETA_ShoppingList* list, NSError* error))completionHandler
{
    
}

- (void) deleteShoppingList:(NSString*)listUUID
                 completion:(void (^)(NSError* error))completionHandler
{
    
}
- (void) getShoppingListModifiedDate:(NSString*)listUUID
                          completion:(void (^)(NSDate* modifiedDate, NSError* error))completionHandler
{
    
}
- (void) getShoppingListShares:(NSString*)listUUID
                    completion:(void (^)(NSArray* users, NSError* error))completionHandler
{
    
}
- (void) shareShoppingList:(NSString*)listUUID
                  withUser:(NSString*)email
                properties:(NSDictionary*)properties
                completion:(void (^)(id response, NSError* error))completionHandler
{
    
}

#pragma mark - Items
- (void) getShoppingListItemsForShoppingList:(NSString*)listUUID
                                  completion:(void (^)(NSArray* shoppingListItems, NSError* error))completionHandler
{
    
}
- (void) createShoppingListItem:(NSString*)itemUUID
                 withProperties:(NSDictionary*)itemProperties
                 inShoppingList:(NSString*)listUUID
                     completion:(void (^)(id item, NSError* error))completionHandler
{
}
- (void) deleteShoppingListItem:(NSString *)itemUUID
                     completion:(void (^)(NSError *))completionHandler
{

}
- (void) deleteAllShoppingListItemsFromShoppingList:(NSString *)listUUID
                                             filter:(NSString*)filter
                                         completion:(void (^)(NSError *))completionHandler
{

}

#pragma mark - Permissions

- (BOOL) canReadShoppingLists
{
    NSString* userID = self.userID;
    if (userID)
        return [self.eta allowsPermission:[NSString stringWithFormat:@"api.users.%@.read",userID]];
    else
        return NO;
}
- (BOOL) canWriteShoppingLists
{
    NSString* userID = self.userID;
    if (userID)
        return [self.eta allowsPermission:[NSString stringWithFormat:@"api.users.%@.update",userID]];
    else
        return NO;
    return NO;
}


+ (NSString*) generateUUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return [(__bridge NSString *)string lowercaseString];
}







//
//+ (NSDictionary*) localDBTableProperties
//{
//    static NSDictionary* tableProperties = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        NSDictionary* SLProps = @{ @"fieldNames": @[kSL_ID,
//                                                    kSL_MODIFIED,
//                                                    kSL_ERN,
//                                                    kSL_NAME,
//                                                    kSL_ACCESS,
//                                                    kSL_STATE,
//                                                    kSL_OWNER_USER,
//                                                    kSL_OWNER_ACCESS,
//                                                    kSL_OWNER_ACCEPTED],
//                                   @"fieldDescriptions": @{  kSL_ID: @"text primary key",
//                                                             kSL_MODIFIED: @"text not null",
//                                                             kSL_ERN: @"text",
//                                                             kSL_NAME: @"text not null",
//                                                             kSL_ACCESS: @"text not null",
//                                                             kSL_STATE: @"integer not null",
//                                                             kSL_OWNER_USER: @"text",
//                                                             kSL_OWNER_ACCESS: @"text",
//                                                             kSL_OWNER_ACCEPTED: @"integer",
//                                                             },
//                                   @"jsonKeyPaths": @{ kSL_ID: @"id",
//                                                       kSL_MODIFIED: @"modified",
//                                                       kSL_ERN: @"ern",
//                                                       kSL_NAME: @"name",
//                                                       kSL_ACCESS: @"access",
//                                                       //kSL_STATE: NSNull.null,
//                                                       kSL_OWNER_USER: @"owner.user",
//                                                       kSL_OWNER_ACCESS: @"owner.access",
//                                                       kSL_OWNER_ACCEPTED: @"owner.accepted",
//                                                       },
//                                   };
//
//        NSDictionary* SLIProps = @{ @"fieldNames": @[kSLI_ID,
//                                                     kSLI_ERN,
//                                                     kSLI_MODIFIED,
//                                                     kSLI_DESCRIPTION,
//                                                     kSLI_COUNT,
//                                                     kSLI_TICK,
//                                                     kSLI_OFFER_ID,
//                                                     kSLI_CREATOR,
//                                                     kSLI_SHOPPING_LIST_ID,
//                                                     kSLI_STATE,
//                                                     ],
//                                    @"fieldDescriptions": @{kSLI_ID: @"text primary key",
//                                                            kSLI_ERN: @"text not null",
//                                                            kSLI_MODIFIED: @"text not null",
//                                                            kSLI_DESCRIPTION: @"text",
//                                                            kSLI_COUNT: @"integer not null",
//                                                            kSLI_TICK: @"integer not null",
//                                                            kSLI_OFFER_ID: @"text",
//                                                            kSLI_CREATOR: @"text not null",
//                                                            kSLI_SHOPPING_LIST_ID: @"text not null",
//                                                            kSLI_STATE: @"integer not null",
//                                                            }
//                                    };
//        tableProperties = @{ kSL_TBLNAME: SLProps,
//                             kSL_USERLESS_TBLNAME: SLProps,
//                             kSLI_TBLNAME: SLIProps,
//                             kSLI_USERLESS_TBLNAME: SLIProps,
//                             };
//    });
//    return tableProperties;
//}
//
//+ (NSDictionary*) localDBTablePropertiesForTable:(NSString*)tableName
//{
//    if (!tableName)
//        return nil;
//    else
//        return [self localDBTableProperties][tableName];
//}
//+ (NSArray*) localDBFieldNamesInTable:(NSString*)tableName
//{
//    return [self localDBTablePropertiesForTable:tableName][@"fieldNames"];
//}
//+ (NSString*) localDBFieldDescriptionForField:(NSString*)fieldName inTable:(NSString*)tableName
//{
//    if (!fieldName)
//        return nil;
//
//    NSDictionary* fieldDescriptions = [self localDBTablePropertiesForTable:tableName][@"fieldDescriptions"];
//    return fieldDescriptions[fieldName];
//}
//+ (NSString*) localDBJSONKeyPathForField:(NSString*)fieldName inTable:(NSString*)tableName
//{
//    if (!fieldName)
//        return nil;
//
//    NSDictionary* keyPaths = [self localDBTablePropertiesForTable:tableName][@"jsonKeyPaths"];
//    return keyPaths[fieldName];
//}
//
//+ (NSDictionary*) localDBParameterDictionaryFromShoppingList:(ETA_ShoppingList*)list
//{
//    NSMutableDictionary* dict = [@{} mutableCopy];
//    dict[kSL_ID] = list.uuid;
//    dict[kSL_MODIFIED] = [[ETA_ShoppingList dateFormatter] stringFromDate:list.modified];
//    dict[kSL_ERN] = list.ern;
//    dict[kSL_NAME] = list.name;
//    dict[kSL_ACCESS] = list.access;
//    dict[kSL_STATE] = @(ETA_ShoppingListObjectState_Init);
////    dict[kSL_OWNER_USER] = nil;
////    dict[kSL_OWNER_ACCESS] = nil;
////    dict[kSL_OWNER_ACCEPTED] = nil;
//    return dict;
//}



@end
