//
//  ETA_ShoppingListManager.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ShoppingListManager.h"
#import "ETA.h"

#import "ETA_User.h"
#import "ETA_Session.h"

#import "ETA_ShoppingList.h"
#import "ETA_ShoppingListItem.h"

#import "ETA_ShoppingList+FMDB.h"
#import "ETA_ShoppingListItem+FMDB.h"

#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

NSString* const ETA_ShoppingListManager_ListsChangedNotification = @"ETA_ShoppingListManager_ListsChangedNotification";
NSString* const ETA_ShoppingListManager_ItemsChangedNotification = @"ETA_ShoppingListManager_ItemsChangedNotification";


NSTimeInterval const kETA_ShoppingListManager_DefaultPollInterval   = 6.0; // secs
NSTimeInterval const kETA_ShoppingListManager_SlowPollInterval      = 10.0; // secs

NSTimeInterval const kETA_ShoppingListManager_DefaultRetrySyncInterval = 10.0; // secs
NSUInteger const kETA_ShoppingListManager_DefaultRetryCount = 5;


NSString* const kSL_TBLNAME             = @"shoppinglists";
NSString* const kSL_USERLESS_TBLNAME    = @"userless_shoppinglists";

NSString* const kSLI_TBLNAME            = @"shoppinglistitems";
NSString* const kSLI_USERLESS_TBLNAME   = @"userless_shoppinglistitems";


@interface ETA_ShoppingListManager ()
@property (nonatomic, readwrite, strong) ETA* eta;
@property (nonatomic, readwrite, strong) NSString* userID; // the userID that the shopping lists were last got for

@property (nonatomic, readwrite, strong) FMDatabaseQueue *dbQ;


@property (nonatomic, readwrite, strong) NSTimer* pollingTimer;

@property (nonatomic, readwrite, strong) NSTimer* retrySyncTimer;
@property (nonatomic, readwrite, assign) NSTimeInterval retrySyncInterval;

@property (nonatomic, readwrite, strong) NSMutableSet* objIDsWithLocalChanges;
@end


@implementation ETA_ShoppingListManager
@synthesize userID = _userID;

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
        
        _pollRate = ETA_ShoppingListManager_PollRate_Default;
        self.pollingTimer = nil;
        
        self.retrySyncTimer = nil;
        self.retrySyncInterval = kETA_ShoppingListManager_DefaultRetrySyncInterval;
        
        self.objIDsWithLocalChanges = [NSMutableSet set];
        
        self.ignoreAttachedUser = NO;
        
        self.verbose = NO;
    }
    return self;
}

- (void) dealloc
{
    [self stopPollingServer];
    [self stopRetrySyncTimer];
    
    self.eta = nil;
    self.dbQ = nil;
}



- (void) log:(NSString*)format, ...
{
    if (!self.verbose)
        return;
    
    va_list args;
    va_start(args, format);
    NSString* msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"[ETA_ShoppingListManager] %@", msg);
}



#pragma mark - User management

- (void) setEta:(ETA *)eta
{
    if (_eta == eta)
        return;
    
    
    [_eta removeObserver:self forKeyPath:@"client.session"];
    
    _eta = eta;
    
    [_eta addObserver:self forKeyPath:@"client.session" options:0 context:NULL];
    
    self.userID = _eta.attachedUserID;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"client.session"])
    {
        self.userID = _eta.attachedUserID;
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void) setUserID:(NSString *)userID
{
    if (_userID == userID || [userID isEqualToString:_userID])
        return;
    
    [self log: @"UserID changed '%@'=>'%@'", _userID, userID];
    _userID = userID;
    
    NSUInteger unresolvedLocalChanges = self.objIDsWithLocalChanges.count;
    if (unresolvedLocalChanges)
        [self log: @"User changed with %d unresolved changes!", unresolvedLocalChanges];
    
    [self.objIDsWithLocalChanges removeAllObjects];
    [self stopRetrySyncTimer];
    if (_userID)
    {
        NSString* prevUserID = [[NSUserDefaults standardUserDefaults] stringForKey:@"ETA_ShoppingListManager_localDBUserID"];
        [[NSUserDefaults standardUserDefaults] setValue:_userID forKey:@"ETA_ShoppingListManager_localDBUserID"];
        
        // attempt to retry any un-synced objects if it's the same user as last time
        if ([prevUserID isEqualToString:_userID])
        {
            [self retryIncompleteSyncs:YES];
        }
        // otherwise, clear the user table, so that we don't we force a resync of the wrong user's items
        else
        {
            //TODO: What if there are non-synced objects!?! User loses unsaved changes!
            [self localDBClearTablesForUserID:_userID];
        }
        
        [self restartPollingServer];
    } else {
        [self stopPollingServer];
    }
}


- (NSString*) userID
{
    if(self.ignoreAttachedUser)
        return nil;
    else
        return _userID;
}


#pragma mark - Public Methods

#pragma mark Shopping Lists

// create and add a totally new shopping list
- (ETA_ShoppingList*) createShoppingList:(NSString*)name
{
    ETA_ShoppingList* shoppingList = [ETA_ShoppingList shoppingListWithUUID:[[self class] generateUUID]
                                                                       name:name
                                                               modifiedDate:nil
                                                                     access:ETA_ShoppingList_Access_Private];
    [self addShoppingList:shoppingList];
    return shoppingList;
}

// add the specified shopping list
- (void) addShoppingList:(ETA_ShoppingList*)list
{
    [self updateShoppingList:list];
}

- (void) updateShoppingList:(ETA_ShoppingList*)list
{
    if (!list.uuid)
        return;
    
    NSString* userID = self.userID;
    
    BOOL isAdding = ([self localDBContainsShoppingListWithID:list.uuid userID:userID] == NO);
    
    list.modified = [NSDate date];
    
    // we are logged in - try to sending to the server
    if (userID)
    {
        [self syncObjectToServer:list remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID];
    }
    // no user - simply send the list to the local db
    else
    {
        [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:list userID:userID];
    }
    
    if (isAdding)
        [self sendNotificationForAdded:@[list] removed:nil modified:nil type:ETA_ShoppingList.class];
    else
        [self sendNotificationForAdded:nil removed:nil modified:@[list] type:ETA_ShoppingList.class];
}


- (void) removeShoppingList:(ETA_ShoppingList*)list
{
    if (!list.uuid)
        return;
    
    // are we adding to the local or server list?
    NSString* userID = self.userID;
    
    list.modified = [NSDate date];
    
    // we are logged in - try to remove from the server
    if (userID)
    {
        [self deleteObjectFromServer:list remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID];
    }
    // no user - simply delete list and all it's items from the local db
    else
    {
        // this will do the delete from the server
        [self localDBUpdateSyncState:ETA_DBSyncState_Deleted forObject:list userID:userID];
    }
    
    [self sendNotificationForAdded:nil removed:@[list] modified:nil type:ETA_ShoppingList.class];
}

- (ETA_ShoppingList*) getShoppingList:(NSString*)listID
{
    return [self localDBGetShoppingList:listID userID:self.userID];
}

- (NSArray*) getAllShoppingLists
{
    return [self localDBGetAllShoppingListsForUserID:self.userID];
}




#pragma mark Shopping List Items

- (ETA_ShoppingListItem *) createShoppingListItem:(NSString *)name inList:(NSString*)listID
{
    if (!name || !listID)
        return nil;
    
    ETA_ShoppingListItem* item = [[ETA_ShoppingListItem alloc] initWithDictionary:@{@"uuid":[[self class] generateUUID],
                                                                                    @"name": name,
                                                                                    @"shoppingListID": listID,
                                                                                    }
                                                                            error:nil];
    item.creator = self.eta.attachedUser.email;
    
    [self addShoppingListItem:item];
    
    return item;
}

- (void) addShoppingListItem:(ETA_ShoppingListItem *)item
{
    [self updateShoppingListItem:item];
}

- (void) updateShoppingListItem:(ETA_ShoppingListItem*)item
{
    if (!item.uuid)
        return;
    
    NSString* userID = self.userID;
    
    BOOL isAdding = ([self localDBContainsShoppingListItemWithID:item.uuid userID:userID] == NO);
    
    item.modified = [NSDate date];
    
    // we are logged in - try to sending to the server
    if (userID)
    {
        [self syncObjectToServer:item remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID];
    }
    // no user - simply send the item to the local db
    else
    {
        [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:item userID:userID];
    }
    
    // recalc the orderID for all the items when something changed on the server
    NSArray* allItems = [self localDBGetAllShoppingListItemsForShoppingList:item.shoppingListID withFilter:ETA_ShoppingListItemFilter_All userID:userID];
    [self localDBUpdateSortOrderIndexesForItems:allItems userID:userID];
    

    if (isAdding)
        [self sendNotificationForAdded:@[item] removed:nil modified:nil type:ETA_ShoppingListItem.class];
    else
        [self sendNotificationForAdded:nil removed:nil modified:@[item] type:ETA_ShoppingListItem.class];
    
}

- (void) removeShoppingListItem:(ETA_ShoppingListItem *)item
{
    if (!item.uuid)
        return;
    
    // are we adding to the local or server list?
    NSString* userID = self.userID;
    
    item.modified = [NSDate date];
    
    
    // update the modified of the list that contains the item
    ETA_ShoppingList* list = [self getShoppingList:item.shoppingListID];
    [self updateShoppingList:list];
    
    // we are logged in - try to remove from the server
    if (userID)
    {
        [self deleteObjectFromServer:item remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID];
    }
    // no user - simply delete list and all it's items from the local db
    else
    {
        // this will do the delete from the server
        [self localDBUpdateSyncState:ETA_DBSyncState_Deleted forObject:item userID:userID];
    }
    
    [self sendNotificationForAdded:nil removed:@[item] modified:nil type:ETA_ShoppingListItem.class];
}

- (void) removeAllShoppingListItemsFromList:(ETA_ShoppingList*)list filter:(ETA_ShoppingListItemFilter)filter
{
    if (!list.uuid)
        return;
    
    // are we adding to the local or server list?
    NSString* userID = self.userID;
    
    
    NSArray* localItems = [self localDBGetAllShoppingListItemsForShoppingList:list.uuid withFilter:filter userID:userID];
    for (ETA_ShoppingListItem* item in localItems)
    {
        item.modified = [NSDate date];
        
        // if not logged in then simply delete all the items from the local db
        if (!userID)
            [self localDBUpdateSyncState:ETA_DBSyncState_Deleted forObject:item userID:userID];
    }
    
    // update the modified of the list that contains the item
    [self updateShoppingList:list];

    
    // we are logged in - try to remove from the server
    if (userID)
    {
        [self deleteShoppingListItemsFromServer:filter fromShoppingList:list.uuid remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID];
    }
    
    [self sendNotificationForAdded:nil removed:localItems modified:nil type:ETA_ShoppingListItem.class];
}


- (ETA_ShoppingListItem*) getShoppingListItem:(NSString*)itemID
{
    return [self localDBGetShoppingListItem:itemID userID:self.userID];
}

- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID
{
    return [self getAllShoppingListItemsInList:listID withFilter:ETA_ShoppingListItemFilter_All];
}

- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter
{
    return [self localDBGetAllShoppingListItemsForShoppingList:listID withFilter:filter userID:self.userID];
}







#pragma mark - Polling

- (void) setPollRate:(ETA_ShoppingListManager_PollRate)pollRate
{
    if (_pollRate == pollRate)
        return;
    
    _pollRate = pollRate;
    
    if (pollRate == ETA_ShoppingListManager_PollRate_None)
        [self stopPollingServer];
    else
        [self restartPollingServer];
}

- (NSTimeInterval) pollIntervalForPollRate:(ETA_ShoppingListManager_PollRate)pollRate
{
    switch (pollRate)
    {
        case ETA_ShoppingListManager_PollRate_Slow:
            return kETA_ShoppingListManager_SlowPollInterval;
            break;
        case ETA_ShoppingListManager_PollRate_None:
            return 0;
            break;
        case ETA_ShoppingListManager_PollRate_Default:
        default:
            return kETA_ShoppingListManager_DefaultPollInterval;
            break;
    }
}

- (void) startPollingServer
{
    if (!self.isPolling && self.pollRate != ETA_ShoppingListManager_PollRate_None)
    {
        self.pollingTimer = [NSTimer timerWithTimeInterval:[self pollIntervalForPollRate:self.pollRate]
                                                    target:self
                                                  selector:@selector(pollingTimerEvent:)
                                                  userInfo:[@{@"pollCount": @(0)} mutableCopy]
                                                   repeats:YES];
        
        // explicitly add to main run loop, in case start is being called from a bg thread
        [[NSRunLoop mainRunLoop] addTimer:self.pollingTimer forMode:NSDefaultRunLoopMode];
        
        [self.pollingTimer fire];
    }
}

- (void) stopPollingServer
{
    [self.pollingTimer invalidate];
    self.pollingTimer = nil;
}

- (void) restartPollingServer
{
    [self stopPollingServer];
    [self startPollingServer];
}

- (BOOL) isPolling
{
    return self.pollingTimer.isValid;
}

- (void) pollingTimerEvent:(NSTimer*)timer
{
    // after how many item polls do we call the list poll
    NSUInteger itemPollsBetweenListPoll = 2;
    
    NSMutableDictionary* userInfo = timer.userInfo;
    NSInteger pollCount = [userInfo[@"pollCount"] integerValue];
    
    userInfo[@"pollCount"] = (pollCount < itemPollsBetweenListPoll) ? @(pollCount+1) : @(0);
    
    
    NSString* userID = self.userID;
    
    // there must be a connected user to make sense
    if (!userID)
        return;
    
    // we are in the process of syncing data to the server, so ignore server changes
    if ([self thereAreObjectsWithLocalChanges])
        return;
    
    [self log: @"[POLLING] %d", pollCount];
    // every first poll ask for all the lists, not just the modified's of the local lists
    if (pollCount == 0)
    {
        [self syncAllShoppingListChangesFromServer:userID];
    }
    else
    {
        [self syncModifiedShoppingListChangesFromServer:userID];
    }
}



#pragma mark - Server => Local

// ask the server for the specified shoppinglist
// find/save/notify of the differences between the local and server versions of this list
- (void) syncShoppingListChangesFromServer:(NSString*)listID userID:(NSString*)userID
{
    // ask for the shopping lists
    [self serverGetShoppingList:listID
                        forUser:userID
                     completion:^(ETA_ShoppingList *serverList, NSError *error) {
                         
                         // the user has changed since we made the server request - the server results are invalid
                         if ([self.userID isEqualToString:userID] == NO)
                             return;
                         
                         // we are in the process of syncing objects, or something went wrong while syncing an object,
                         // meaning the local version has changes that arent on the server yet
                         // ignore any changes the server has
                         if ([self thereAreObjectsWithLocalChanges])
                             return;
                         
                         
                         if (!error && serverList)
                         {
                             ETA_ShoppingList* localList = [self localDBGetShoppingList:listID userID:userID];
                             [self saveLocallyAndNotifyChangesBetweenLocalShoppingLists:@[localList] andListsFromServer:@[serverList] userID:userID];
                         }
                         else
                         {
                             [self log: @"[SERVER=>LOCAL LISTS] !!! failed getting list %@ for userID %@ : %@ / %@", listID, userID, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                         }
                     }];
}


// ask the server for all the shoppinglists
// for each list that is returned, find/save/notify of the differences
- (void) syncAllShoppingListChangesFromServer:(NSString*)userID
{
    // ask for the shopping lists
    [self serverGetAllShoppingListsForUser:userID
                                completion:^(NSArray *serverLists, NSError *error) {
                                    
                                    // the user has changed since we made the server request - the server results are invalid
                                    if ([self.userID isEqualToString:userID] == NO)
                                        return;
                                    
                                    // we are in the process of syncing objects, or something went wrong while syncing an object,
                                    // meaning the local version has changes that arent on the server yet
                                    // ignore any changes the server has
                                    if ([self thereAreObjectsWithLocalChanges])
                                        return;
                                    
                                    if (!error)
                                    {
                                        NSArray* localLists = [self localDBGetAllShoppingListsForUserID:userID];
                                        [self saveLocallyAndNotifyChangesBetweenLocalShoppingLists:localLists andListsFromServer:serverLists userID:userID];
                                    }
                                    else
                                    {
                                        [self log: @"[SERVER=>LOCAL LISTS] !!! failed getting all lists userID %@ : %@ / %@", userID, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                                    }
                                }];
}

// get the modified dates for each local shopping list
// for each shopping list that was modified more recently on the server, get all the items
// do a sync of the items
- (void) syncModifiedShoppingListChangesFromServer:(NSString*)userID
{
    NSArray* localLists = [self localDBGetAllShoppingListsForUserID:userID];
    
    for (ETA_ShoppingList* list in localLists)
    {
        NSDate* localModifiedDate = list.modified;
        NSString* listID = list.uuid;
        [self serverGetModifiedDateForShoppingList:listID
                                           forUser:userID
                                        completion:^(NSDate *serverModifiedDate, NSError *error) {
                                            // the server's modified date is newer than the local list's modified date
                                            if (!error && serverModifiedDate && (!localModifiedDate || [serverModifiedDate compare:localModifiedDate] == NSOrderedDescending))
                                            {
                                                // sync the changes for the list that changed - this will get and sync the items too
                                                [self syncShoppingListChangesFromServer:listID userID:userID];
                                            }
                                            else if (error)
                                            {
                                                [self log: @"[SERVER=>LOCAL ITEMS] !!! Failed Getting modified for List '%@' : %@ / %@",listID, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                                            }
                                            
                                        }];
    }
}

- (void) syncShoppingListItemChangesFromServerForList:(NSString*)listID userID:(NSString*)userID
{
    [self serverGetAllShoppingListItemsInShoppingList:listID
                                              forUser:userID
                                           completion:^(NSArray *serverItems, NSError *error) {
                                               // the user has changed since we made the server request - the server results are invalid
                                               if ([self.userID isEqualToString:userID] == NO)
                                                   return;
                                               
                                               // we are in the process of syncing objects, or something went wrong while syncing an object,
                                               // meaning the local version has changes that arent on the server yet
                                               // ignore any changes the server has
                                               if ([self thereAreObjectsWithLocalChanges])
                                                   return;
                                               
                                               if (!error)
                                               {
                                                   NSArray* localItems = [self localDBGetAllShoppingListItemsForShoppingList:listID
                                                                                                                  withFilter:ETA_ShoppingListItemFilter_All
                                                                                                                      userID:userID];
                                                   [self log: @"[SERVER=>LOCAL ITEMS] successfully got %d server, %d local for list: %@", serverItems.count, localItems.count, listID];
                                                   
                                                   [self saveLocallyAndNotifyChangesBetweenLocalShoppingListItems:localItems andItemsFromServer:serverItems userID:userID];
                                               }
                                               else
                                               {
                                                   [self log: @"[SERVER=>LOCAL ITEMS] failure getting items for list '%@': %@ / %@",listID, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                                               }
                                           }];
}


#pragma mark Change merging

// go through the lists of local and server objects, comparing them
// returns a dict of the objects that have been 'added' to the server, 'removed' from the server, or 'modified' more recently on the server
// this works with any ETA_ModelObject that has a 'modified' property
// mergeHandler allows for merging of the local object into the server object, returning a new object that will be used added to the differences dict
- (NSDictionary*) getDifferencesBetweenLocalObjects:(NSArray*)localObjects andServerObjects:(NSArray*)serverObjects mergeHandler:(ETA_ModelObject* (^)(ETA_ModelObject* serverObject, ETA_ModelObject* localObject))mergeHandler
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
            [self log: @"Got a server object without a UUID... should not happen! %@", serverObj];
            return;
        }

        ETA_ModelObject* localObj = localObjectsByUUID[serverObj.uuid];
        
        if (mergeHandler)
            serverObj = mergeHandler([serverObj copy], [localObj copy]);
        
        if (!serverObj.uuid)
        {
            [self log: @"After merging the server object didnt have a UUID! %@", serverObj];
            return;
        }
        
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

- (void) saveLocallyAndNotifyChangesBetweenLocalShoppingLists:(NSArray*)localLists andListsFromServer:(NSArray*)serverLists userID:(NSString*)userID
{
    NSDictionary* differencesDict = [self getDifferencesBetweenLocalObjects:localLists andServerObjects:serverLists mergeHandler:nil];
    
    NSArray* removed = differencesDict[@"removed"];
    NSArray* added = differencesDict[@"added"];
    NSArray* modified = differencesDict[@"modified"];
    
    NSUInteger changeCount = removed.count + added.count + modified.count;
    if (changeCount == 0)
        return;
    
    [self log: @"[SERVER=>LOCAL LISTS] list changes - %d added / %d removed / %d modified", added.count, removed.count, modified.count];
    
    [removed enumerateObjectsUsingBlock:^(ETA_ShoppingList* list, NSUInteger idx, BOOL *stop) {
        // this will do the delete from the local DB
        [self localDBUpdateSyncState:ETA_DBSyncState_Deleted forObject:list userID:userID];
    }];

    [added enumerateObjectsUsingBlock:^(ETA_ShoppingList* list, NSUInteger idx, BOOL *stop) {
        [self localDBUpdateSyncState:ETA_DBSyncState_Synced forObject:list userID:userID];
        
        // get items for this list from the server and save locally, and notify
        [self syncShoppingListItemChangesFromServerForList:list.uuid userID:userID];
    }];
    
    [modified enumerateObjectsUsingBlock:^(ETA_ShoppingList* list, NSUInteger idx, BOOL *stop) {
        [self localDBUpdateSyncState:ETA_DBSyncState_Synced forObject:list userID:userID];
        
        // get items for this list from the server and save locally, and notify
        [self syncShoppingListItemChangesFromServerForList:list.uuid userID:userID];
    }];
    
    
    if (differencesDict.count)
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_ShoppingListManager_ListsChangedNotification
                                                            object:self
                                                          userInfo:differencesDict];
}

- (void) saveLocallyAndNotifyChangesBetweenLocalShoppingListItems:(NSArray*)localItems andItemsFromServer:(NSArray*)serverItems userID:(NSString*)userID
{
    NSDictionary* differencesDict = [self getDifferencesBetweenLocalObjects:localItems
                                                           andServerObjects:serverItems
                                                               mergeHandler:^ETA_ModelObject *(ETA_ModelObject *serverObject, ETA_ModelObject *localObject) {
                                                                   // if the server doesnt define a prevItemID then use the local item's prevItemID
                                                                   // this allows for the server not implementing this feature yet
                                                                   NSString* serverPrevID = ((ETA_ShoppingListItem*)serverObject).prevItemID;
                                                                   NSString* localPrevID = ((ETA_ShoppingListItem*)localObject).prevItemID;
                                                                   if (!serverPrevID)
                                                                       ((ETA_ShoppingListItem*)serverObject).prevItemID = localPrevID;
                                                                   
                                                                   return serverObject;
                                                               }];
    
    NSArray* removed = differencesDict[@"removed"];
    NSArray* added = differencesDict[@"added"];
    NSArray* modified = differencesDict[@"modified"];
    
    NSUInteger changeCount = removed.count + added.count + modified.count;
    if (changeCount == 0)
        return;
    
    [self log: @"[SERVER=>LOCAL ITEMS] item changes - %d added / %d removed / %d modified", added.count, removed.count, modified.count];
    
    [removed enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* item, NSUInteger idx, BOOL *stop) {
        [self localDBDeleteShoppingListItem:item.uuid userID:userID];
    }];
    
    [added enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* item, NSUInteger idx, BOOL *stop) {
        [self localDBInsertOrReplaceShoppingListItem:item userID:userID];
    }];
    
    [modified enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* item, NSUInteger idx, BOOL *stop) {
        [self localDBInsertOrReplaceShoppingListItem:item userID:userID];
    }];
    
    
    // recalc the orderID for all the items when something changed on the server
    NSArray* allItems = [self localDBGetAllShoppingListItemsForShoppingList:nil withFilter:ETA_ShoppingListItemFilter_All userID:userID];
    [self localDBUpdateSortOrderIndexesForItems:allItems userID:userID];
    
    
    [self sendNotificationForAdded:added removed:removed modified:modified type:ETA_ShoppingListItem.class];
}


- (void) sendNotificationForAdded:(NSArray*)added removed:(NSArray*)removed modified:(NSArray*)modified type:(Class)type
{
    NSString* notificationName = nil;
    if (type == ETA_ShoppingListItem.class)
    {
        notificationName = ETA_ShoppingListManager_ItemsChangedNotification;
    } else if (type == ETA_ShoppingList.class)
    {
        notificationName = ETA_ShoppingListManager_ListsChangedNotification;
    }
    else
        return;
    
    NSMutableDictionary* differencesDict = [NSMutableDictionary dictionaryWithCapacity:3];
    
    if (removed.count)
        differencesDict[@"removed"] = removed;
    
    if (added.count)
        differencesDict[@"added"] = added;
    
    if (modified.count)
        differencesDict[@"modified"] = modified;
    
    if (differencesDict.count)
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                            object:self
                                                          userInfo:differencesDict];
}
#pragma mark - Local => Server

- (BOOL) thereAreObjectsWithLocalChanges
{
    return (self.objIDsWithLocalChanges.count > 0);
}

- (void) deleteObjectFromServer:(ETA_DBSyncModelObject*)objToDelete remainingRetries:(NSUInteger)remainingRetries userID:(NSString*)userID
{
    // cant delete from server if not connected
    if (!userID)
        return;
    
    // mark the list as in the process of being deleted
    [self localDBUpdateSyncState:ETA_DBSyncState_Deleting forObject:objToDelete userID:userID];
    
    
    // send delete request to the server
    [self serverDeleteObject:objToDelete
                     forUser:userID
                  completion:^(NSError *error) {
                            
                            // the user changed to a different user (not just logged off) while the request was being sent
                            // we cannot use the response for anything now
                            if (self.userID && [self.userID isEqualToString:userID]==NO)
                                return;
                            
                            // success! delete from the local store
                            if (!error)
                            {
                                [self log: @"[DELETE %@] successfully deleted '%@'(%@)", NSStringFromClass(objToDelete.class), ((ETA_ShoppingList*)objToDelete).name, objToDelete.uuid];
                                
                                // this will do the delete from the server
                                [self localDBUpdateSyncState:ETA_DBSyncState_Deleted forObject:objToDelete userID:userID];
                                
                                // stop the retry timer if there are no more objects that need to be synced
                                if ([self thereAreObjectsWithLocalChanges] == NO)
                                    [self stopRetrySyncTimer];
                            }
                            // for some reason we couldnt delete the object - remember it and retry
                            else
                            {
                                [self log: @"[DELETE %@] failed (%d remaining) to delete '%@'(%@) - %@ / %@", NSStringFromClass(objToDelete.class), remainingRetries, ((ETA_ShoppingList*)objToDelete).name, objToDelete.uuid, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                                
                                // mark as needing to be deleted
                                [self localDBUpdateSyncState:ETA_DBSyncState_ToBeDeleted forObject:objToDelete userID:userID];
                                
                                // we failed too many times - start a timer that will retry the deletes
                                if (remainingRetries <= 0)
                                {
                                    [self startRetrySyncTimer];
                                }
                                // retry deleting the object from the server
                                else
                                {
                                    [self deleteObjectFromServer:objToDelete remainingRetries:remainingRetries-1 userID:userID];
                                }
                            }
                        }];
}

- (void) syncObjectToServer:(ETA_DBSyncModelObject*)objToSync remainingRetries:(NSUInteger)remainingRetries userID:(NSString*)userID
{
    // cant sync if not connected
    if (!userID)
        return;
    
    [self localDBUpdateSyncState:ETA_DBSyncState_Syncing forObject:objToSync userID:userID];

    
    [self log: @"[SYNC %@] started '%@' (%@)", NSStringFromClass([objToSync class]), [(ETA_ShoppingList*)objToSync name], objToSync.uuid];
    
    // send request to insert/update to server
    [self serverInsertOrReplaceObject:objToSync
                              forUser:userID
                           completion:^(ETA_DBSyncModelObject* syncedObj, NSError *error) {
                                     
                                     // the user changed to a different user (not just logged off) while the request was being sent
                                     // we cannot use the response for anything now
                                     if (self.userID && [self.userID isEqualToString:userID]==NO)
                                         return;
                                     
                                     // on success, mark as synced
                                     if (!error && syncedObj)
                                     {
                                         [self log: @"[SYNC %@] successfully synced '%@'(%@)", NSStringFromClass([syncedObj class]), [(ETA_ShoppingList*)syncedObj name], syncedObj.uuid];
                                         
                                         // mark locally as having been successfully synced (and save returned list back to localDB
                                         [self localDBUpdateSyncState:ETA_DBSyncState_Synced forObject:syncedObj userID:userID];
                                         
                                         // stop the retry timer if there are no more objects that need to be synced
                                         if ([self thereAreObjectsWithLocalChanges] == NO)
                                             [self stopRetrySyncTimer];
                                     }
                                     // something bad happened while trying to send changes to the server
                                     else
                                     {
                                         [self log: @"[SYNC %@] failed (%d remaining) to sync list '%@'(%@) - %@ / %@", NSStringFromClass([objToSync class]),remainingRetries, [(ETA_ShoppingList*)objToSync name], objToSync.uuid, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                                         
                                         // mark as un-synced
                                         [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:objToSync userID:userID];
                                         
                                         
                                         // we failed too many times - start a timer that will retry the syncs
                                         if (remainingRetries <= 0)
                                         {
                                             [self startRetrySyncTimer];
                                         }
                                         // retry sending the list to the server
                                         else
                                         {
                                             [self syncObjectToServer:objToSync remainingRetries:remainingRetries-1 userID:userID];
                                         }
                                     }
                                 }];
}


- (void) deleteShoppingListItemsFromServer:(ETA_ShoppingListItemFilter)filter fromShoppingList:(NSString*)listID remainingRetries:(NSUInteger)remainingRetries userID:(NSString*)userID
{
    // cant delete from server if not connected
    if (!userID)
        return;
    
    NSArray* localItems = [self localDBGetAllShoppingListItemsForShoppingList:listID withFilter:filter userID:userID];
    
    // mark the items as in the process of being deleted
    for (ETA_ShoppingListItem* item in localItems)
    {
        [self localDBUpdateSyncState:ETA_DBSyncState_Deleting forObject:item userID:userID];
    }
    
    [self serverDeleteAllShoppingListItems:filter
                          fromShoppingList:listID
                                   forUser:userID
                                completion:^(NSError *error) {
                                    // the user changed to a different user (but not just logged off) while the request was being sent
                                    // we cannot use the response for anything now
                                    if (self.userID && [self.userID isEqualToString:userID]==NO)
                                        return;
                                    
                                    if (!error)
                                    {
                                        for (ETA_ShoppingListItem* item in localItems)
                                        {
                                            [self localDBUpdateSyncState:ETA_DBSyncState_Deleted forObject:item userID:userID];
                                        }
                                        
                                        [self sendNotificationForAdded:nil removed:localItems modified:nil type:ETA_ShoppingListItem.class];
                                        
                                        // stop the retry timer if there are no more objects that need to be synced
                                        if ([self thereAreObjectsWithLocalChanges] == NO)
                                            [self stopRetrySyncTimer];
                                    }
                                    else
                                    {
                                        [self log: @"[DELETING ITEMS] failed %@ / %@", error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                                        
                                        // mark as needing to be deleted
                                        for (ETA_ShoppingListItem* item in localItems)
                                        {
                                            [self localDBUpdateSyncState:ETA_DBSyncState_ToBeDeleted forObject:item userID:userID];
                                        }
                                        
                                        // we failed too many times - start a timer that will retry the deletes
                                        if (remainingRetries <= 0)
                                        {
                                            [self startRetrySyncTimer];
                                        }
                                        // retry deleting the object from the server
                                        else
                                        {
                                            [self deleteShoppingListItemsFromServer:filter fromShoppingList:listID remainingRetries:remainingRetries-1 userID:userID];
                                        }
                                    }
                                    
                                }];
}




#pragma mark Retry timer

- (void) startRetrySyncTimer
{
    if ([self.retrySyncTimer isValid] == NO)
    {
        
        self.retrySyncTimer = [NSTimer timerWithTimeInterval:self.retrySyncInterval
                                                      target:self selector:@selector(retryIncompleteSyncsFromTimer:)
                                                    userInfo:nil repeats:YES];
        
        // explicitly add to main run loop, in case start is being called from a bg thread
        [[NSRunLoop mainRunLoop] addTimer:self.retrySyncTimer forMode:NSDefaultRunLoopMode];
    }
}
- (void) stopRetrySyncTimer
{
    [self.retrySyncTimer invalidate];
    self.retrySyncTimer = nil;
}

- (void) retryIncompleteSyncsFromTimer:(NSTimer*)timer
{
    if (!self.userID)
        [self stopRetrySyncTimer];
    
    [self retryIncompleteSyncs:NO];
}



// go through all the un-synced lists and attempt to add them to the server
- (void) retryIncompleteSyncs:(BOOL)includeInProgressSyncs
{
    // only relevant for online syncs
    NSString* userID = self.userID;
    if (!userID)
        return;
    
    NSMutableArray* toBeSynced = [NSMutableArray array];
    NSMutableArray* toBeDeleted = [NSMutableArray array];
    
    [toBeSynced addObjectsFromArray:[self localDBGetAllShoppingListsWithSyncState:ETA_DBSyncState_ToBeSynced userID:userID]];
    [toBeSynced addObjectsFromArray:[self localDBGetAllShoppingListItemsWithSyncState:ETA_DBSyncState_ToBeSynced userID:userID]];
    
    [toBeDeleted addObjectsFromArray:[self localDBGetAllShoppingListsWithSyncState:ETA_DBSyncState_ToBeDeleted userID:userID]];
    [toBeDeleted addObjectsFromArray:[self localDBGetAllShoppingListItemsWithSyncState:ETA_DBSyncState_ToBeDeleted userID:userID]];
    
    if (includeInProgressSyncs)
    {
        [toBeSynced addObjectsFromArray:[self localDBGetAllShoppingListsWithSyncState:ETA_DBSyncState_Syncing userID:userID]];
        [toBeSynced addObjectsFromArray:[self localDBGetAllShoppingListItemsWithSyncState:ETA_DBSyncState_Syncing userID:userID]];
        
        [toBeDeleted addObjectsFromArray:[self localDBGetAllShoppingListsWithSyncState:ETA_DBSyncState_Deleting userID:userID]];
        [toBeDeleted addObjectsFromArray:[self localDBGetAllShoppingListItemsWithSyncState:ETA_DBSyncState_Deleting userID:userID]];
    }
    
    if (toBeSynced.count+toBeDeleted.count)
        [self log: @"[RETRY] retrying %d syncs / %d deletes", toBeSynced.count, toBeDeleted.count];
    
    
    // go through each list, trying to add it to the server
    [toBeSynced enumerateObjectsUsingBlock:^(ETA_DBSyncModelObject* objToSync, NSUInteger idx, BOOL *stop) {
        [self syncObjectToServer:objToSync remainingRetries:0 userID:userID];
    }];
    
    [toBeDeleted enumerateObjectsUsingBlock:^(ETA_DBSyncModelObject* objToDelete, NSUInteger idx, BOOL *stop) {
        [self deleteObjectFromServer:objToDelete remainingRetries:0 userID:userID];
    }];
}




#pragma mark -

#pragma mark - Local DB methods

- (void) localDBCreateTables
{
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        [ETA_ShoppingList createTable:[[self class] localDBTableName_ShoppingList:@"not_nil"] inDB:db];
        [ETA_ShoppingList createTable:[[self class] localDBTableName_ShoppingList:nil] inDB:db];
        
        [ETA_ShoppingListItem createTable:[[self class] localDBTableName_ShoppingListItem:@"not_nil"] inDB:db];
        [ETA_ShoppingListItem createTable:[[self class] localDBTableName_ShoppingListItem:nil] inDB:db];
    }];
}
- (void) localDBClearTablesForUserID:(NSString*)userID
{
    [self.dbQ inDatabase:^(FMDatabase *db) {
        [ETA_ShoppingList clearTable:[[self class] localDBTableName_ShoppingList:userID] inDB:db];
        [ETA_ShoppingListItem clearTable:[[self class] localDBTableName_ShoppingListItem:userID] inDB:db];
    }];
}


- (void) localDBUpdateSyncState:(ETA_DBSyncState)syncState forObject:(ETA_DBSyncModelObject*)obj userID:(NSString*)userID
{
    [self.objIDsWithLocalChanges removeObject:obj.uuid];
    
    BOOL isList = [obj isKindOfClass:ETA_ShoppingList.class];
    BOOL isItem = (isList) ? NO : [obj isKindOfClass:ETA_ShoppingListItem.class];
    
    if (!isItem && !isList)
        return;
    
    // TODO: only update when modified is the same or newer. Use in all localDB methods.
    
    // if it is deleted, remove from the local db
    if (syncState == ETA_DBSyncState_Deleted)
    {
        if (isList)
        {
            [self localDBDeleteShoppingList:obj.uuid userID:userID];
            
            [self localDBDeleteAllItemsForShoppingList:obj.uuid withFilter:ETA_ShoppingListItemFilter_All userID:userID];
        }
        else if (isItem)
        {
            [self localDBDeleteShoppingListItem:obj.uuid userID:userID];
        }
    }
    else
    {
        obj.state = syncState;
        
        // save state to the local db
        if (isList)
            [self localDBInsertOrReplaceShoppingList:(ETA_ShoppingList*)obj userID:userID];
        else if (isItem)
            [self localDBInsertOrReplaceShoppingListItem:(ETA_ShoppingListItem*)obj userID:userID];
        
        
        // for unresolved states, save the obj id
        switch (syncState)
        {
            case ETA_DBSyncState_ToBeSynced:
            case ETA_DBSyncState_Syncing:
            case ETA_DBSyncState_ToBeDeleted:
            case ETA_DBSyncState_Deleting:
            {
                [self.objIDsWithLocalChanges addObject:obj.uuid];
                break;
            }
            default:
                break;
        }
    }
}


#pragma mark Shopping Lists

+ (NSString*) localDBTableName_ShoppingList:(NSString*)userID
{
    return (userID==nil) ? kSL_USERLESS_TBLNAME : kSL_TBLNAME;
}

- (ETA_ShoppingList*) localDBGetShoppingList:(NSString*)listID userID:(NSString*)userID
{
    __block ETA_ShoppingList* list = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingList:userID];
        
        list = [ETA_ShoppingList getListWithID:listID fromTable:tblName inDB:db];
    }];
    return list;
}

- (NSArray*) localDBGetAllShoppingListsForUserID:(NSString*)userID
{
    __block NSArray* lists = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingList:userID];
        
        lists = [ETA_ShoppingList getAllListsFromTable:tblName inDB:db];
    }];
    return lists;
}

- (BOOL) localDBContainsShoppingListWithID:(NSString*)listID userID:(NSString*)userID
{
    __block BOOL exists = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:userID];
        
        exists = [ETA_ShoppingList listExistsWithID:listID inTable:tblName inDB:db];
    }];
    return exists;
}

- (BOOL) localDBInsertOrReplaceShoppingList:(ETA_ShoppingList*)list userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:userID];
        
        success = [ETA_ShoppingList insertOrReplaceList:list intoTable:tblName inDB:db];
    }];
    return success;
}

- (BOOL) localDBDeleteShoppingList:(NSString*)listID userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:userID];
        
        success = [ETA_ShoppingList deleteList:listID fromTable:tblName inDB:db];
    }];
    return success;
}


- (NSArray*) localDBGetAllShoppingListsWithSyncState:(ETA_DBSyncState)syncState userID:(NSString*)userID
{
    __block NSArray* lists = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:userID];
        
        lists = [ETA_ShoppingList getAllListsWithSyncState:syncState fromTable:tblName inDB:db];
    }];
    return lists;
}


#pragma mark Shopping List Items

- (void) localDBUpdateSortOrderIndexesForItems:(NSArray*)items userID:(NSString*)userID
{
    if (!items)
        return;
    
    NSArray* changedItems = [self changeSortOrderIndexesForItems:items];
    
    for (ETA_ShoppingListItem* item in changedItems)
        [self localDBInsertOrReplaceShoppingListItem:item userID:userID];
}

- (NSArray*) changeSortOrderIndexesForItems:(NSArray*)items
{
    NSMutableDictionary* itemsByPrevItemID = [NSMutableDictionary dictionary];
    
    NSMutableArray* changedItems = [NSMutableArray array];
    NSMutableArray* firstItems = [NSMutableArray array];
    
    for (ETA_ShoppingListItem* item in items)
    {
        NSString* prevID = item.prevItemID;
        if (prevID)
        {
            if (prevID.length == 0)
                [firstItems addObject:item];
            else
                itemsByPrevItemID[prevID] = item;
        }
        // it doesnt have a previous item - it isnt in the sorting
        else if (item.orderIndex != -1)
        {
            item.orderIndex = -1;
            [changedItems addObject:item];
        }
    }
    
    for (ETA_ShoppingListItem* firstItem in firstItems)
    {
        NSUInteger orderIndex = 0;
        ETA_ShoppingListItem* nextItem = firstItem;
        
        while (nextItem)
        {
            if (nextItem.orderIndex != orderIndex)
            {
                nextItem.orderIndex = orderIndex;
                [changedItems addObject:nextItem];
            }
            
            // clear from item dict
            [itemsByPrevItemID setValue:nil forKey:nextItem.prevItemID];
            
            // move on to the next item
            nextItem = itemsByPrevItemID[nextItem.uuid];
        }
    }
    
    // mark the remaining unsorted items
    for (ETA_ShoppingListItem* item in itemsByPrevItemID.allValues)
    {
        if (item.orderIndex != -1)
        {
            item.orderIndex = -1;
            [changedItems addObject:item];
        }
    }
    
    return changedItems;
}

+ (NSString*) localDBTableName_ShoppingListItem:(NSString*)userID
{
    return (userID==nil) ? kSLI_USERLESS_TBLNAME : kSLI_TBLNAME;
}

- (ETA_ShoppingListItem*) localDBGetShoppingListItem:(NSString*)itemID userID:(NSString*)userID
{
    __block ETA_ShoppingListItem* item = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        item = [ETA_ShoppingListItem getItemWithID:itemID fromTable:tblName inDB:db];
    }];
    return item;
}

- (NSArray*) localDBGetAllShoppingListItemsForShoppingList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter userID:(NSString*)userID
{
    __block NSArray* items = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        items = [ETA_ShoppingListItem getAllItemsForShoppingList:listID withFilter:filter fromTable:tblName inDB:db];
    }];
    return items;
}

- (NSArray*) localDBGetAllShoppingListItemsWithSyncState:(ETA_DBSyncState)syncState userID:(NSString*)userID
{
    __block NSArray* lists = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        lists = [ETA_ShoppingListItem getAllItemsWithSyncState:syncState fromTable:tblName inDB:db];
    }];
    return lists;
}

- (BOOL) localDBContainsShoppingListItemWithID:(NSString*)itemID userID:(NSString*)userID
{
    __block BOOL exists = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        exists = [ETA_ShoppingListItem itemExistsWithID:itemID inTable:tblName inDB:db];
    }];
    return exists;
}

- (BOOL) localDBInsertOrReplaceShoppingListItem:(ETA_ShoppingListItem*)item userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        success = [ETA_ShoppingListItem insertOrReplaceItem:item intoTable:tblName inDB:db];
    }];
    return success;
}

- (BOOL) localDBDeleteShoppingListItem:(NSString*)itemID userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        success = [ETA_ShoppingListItem deleteItem:itemID fromTable:tblName inDB:db];
    }];
    return success;
}

- (BOOL) localDBDeleteAllItemsForShoppingList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        success = [ETA_ShoppingListItem deleteAllItemsForShoppingList:listID withFilter:filter fromTable:tblName inDB:db];
    }];
    return success;
}






#pragma mark - Server methods


- (void) serverInsertOrReplaceObject:(ETA_DBSyncModelObject *)obj forUser:(NSString*)userID completion:(void (^)(ETA_DBSyncModelObject* responseObj, NSError* error))completionHandler
{
    if ([obj isKindOfClass:ETA_ShoppingList.class])
    {
        [self serverInsertOrReplaceShoppingList:(ETA_ShoppingList*)obj forUser:userID completion:completionHandler];
    }
    else if ([obj isKindOfClass:ETA_ShoppingListItem.class])
    {
        [self serverInsertOrReplaceShoppingListItem:(ETA_ShoppingListItem*)obj forUser:userID completion:completionHandler];
    }
    else if (completionHandler)
    {
        //TODO: Error if invalid obj type
        completionHandler(nil, nil);
    }
}


- (void) serverDeleteObject:(ETA_DBSyncModelObject *)obj forUser:(NSString*)userID completion:(void (^)(NSError* error))completionHandler
{
    if ([obj isKindOfClass:ETA_ShoppingList.class])
    {
        [self serverDeleteShoppingList:(ETA_ShoppingList*)obj forUser:userID completion:completionHandler];
    }
    else if ([obj isKindOfClass:ETA_ShoppingListItem.class])
    {
        [self serverDeleteShoppingListItem:(ETA_ShoppingListItem*)obj forUser:userID completion:completionHandler];
    }
    else if (completionHandler)
    {
        //TODO: Error if invalid obj type
        completionHandler(nil);
    }
}

#pragma mark Shopping Lists

- (void) serverGetShoppingList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(ETA_ShoppingList* list, NSError* error))completionHandler
{
    if (!completionHandler)
        return;
    
    //TODO: error when userID is invalid
    if (!userID)
    {
        completionHandler(nil, nil);
        return;
    }
    
    //   "/v2/users/{userID}/shoppinglists/{listID}"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
                                                       listID]];
    
    [self.eta api:request
             type:ETARequestTypeGET
       parameters:nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           ETA_ShoppingList* list = [ETA_ShoppingList objectFromJSONDictionary:response];
           
           completionHandler(list, error);
       }];
    
}

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
    
    //   "/v2/users/{userID}/shoppinglists"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists]];
    
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

- (void) serverGetModifiedDateForShoppingList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(NSDate* modifiedDate, NSError* error))completionHandler
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
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
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
                   modified = [ETA_API.dateFormatter dateFromString:dateStr];
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
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
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


- (void) serverDeleteShoppingList:(ETA_ShoppingList *)list forUser:(NSString*)userID completion:(void (^)(NSError* error))completionHandler
{
    // TODO: error when userID/list is invalid
    if (!userID || !list || !list.uuid)
    {
        if (completionHandler)
            completionHandler(nil);
        return;
    }
    
    // "/v2/users/{userID}/shoppinglists/{listID}?modified={now}"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
                                                       list.uuid]];
    [self.eta api:request
             type:ETARequestTypeDELETE
       parameters:@{@"modified":[ETA_API.dateFormatter stringFromDate:list.modified]}
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           if (completionHandler)
           {
               completionHandler(error);
           }
       }];
}
#pragma mark Shopping List Items

// go to the server and get the latest state of all the shopping list items
- (void) serverGetAllShoppingListItemsInShoppingList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(NSArray* items, NSError* error))completionHandler
{
    if (!completionHandler)
        return;
    
    //TODO: error when userID is invalid
    if (!userID || !listID)
    {
        completionHandler(nil, nil);
        return;
    }
    
    //   "/v2/users/{userID}/shoppinglists/{listID}/items"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
                                                       listID,
                                                       ETA_API.shoppingListItems]];
    
    [self.eta api:request
             type:ETARequestTypeGET
       parameters:nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           NSMutableArray* items = nil;
           if (!error)
           {
               if ([response isKindOfClass:[NSArray class]] == NO)
                   response = @[response];
               
               items = [@[] mutableCopy];
               for (id obj in response)
               {
                   ETA_ShoppingListItem* shoppingListItem = [ETA_ShoppingListItem objectFromJSONDictionary:obj];
                   if (shoppingListItem)
                   {
                       // ergh - server shopping_list_id is the old API id... make sure we use the new one
                       shoppingListItem.shoppingListID = listID;
                       [items addObject:shoppingListItem];
                   }
               }
           }
           
           completionHandler(items, error);
       }];
}

- (void) serverInsertOrReplaceShoppingListItem:(ETA_ShoppingListItem *)item forUser:(NSString*)userID completion:(void (^)(ETA_ShoppingListItem* syncedItem, NSError* error))completionHandler
{
    // TODO: error when userID/list is invalid
    if (!userID || !item.uuid || !item.description || !item.shoppingListID)
    {
        if (completionHandler)
            completionHandler(nil, nil);
        return;
    }
    
    NSString* listID = item.shoppingListID;
    
    NSMutableDictionary* jsonDict = [[item JSONDictionary] mutableCopy];
    
    // "/v2/users/{userID}/shoppinglists/{listID}/items/{itemID}"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
                                                       listID,
                                                       ETA_API.shoppingListItems,
                                                       item.uuid
                                                       ]];
    [self.eta api:request
             type:ETARequestTypePUT
       parameters:jsonDict
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           if (completionHandler)
           {
               ETA_ShoppingListItem* syncedItem = [ETA_ShoppingListItem objectFromJSONDictionary:response];
               // ergh - server shopping_list_id is the old API id... make sure we use the new one
               syncedItem.shoppingListID = listID;
               
               completionHandler(syncedItem, error);
           }
       }];
}


- (void) serverDeleteShoppingListItem:(ETA_ShoppingListItem *)item forUser:(NSString*)userID completion:(void (^)(NSError* error))completionHandler
{
    // TODO: error when userID/list is invalid
    if (!userID || !item.uuid || !item.shoppingListID)
    {
        if (completionHandler)
            completionHandler(nil);
        return;
    }
    
    // "/v2/users/{userID}/shoppinglists/{listID}/items/{itemID}"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
                                                       item.shoppingListID,
                                                       ETA_API.shoppingListItems,
                                                       item.uuid
                                                       ]];
    [self.eta api:request
             type:ETARequestTypeDELETE
       parameters:nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           if (completionHandler)
           {
               completionHandler(error);
           }
       }];
}



- (void) serverDeleteAllShoppingListItems:(ETA_ShoppingListItemFilter)filter fromShoppingList:(NSString *)listID forUser:(NSString*)userID completion:(void (^)(NSError* error))completionHandler
{
    // TODO: error when userID/list is invalid
    if (!userID || !listID)
    {
        if (completionHandler)
            completionHandler(nil);
        return;
    }
    
    NSDictionary* filterStrings = @{ @(ETA_ShoppingListItemFilter_All): @"all",
                                     @(ETA_ShoppingListItemFilter_Ticked): @"ticked",
                                     @(ETA_ShoppingListItemFilter_Unticked): @"unticked",
                                     };
    NSString* filterStr = [filterStrings objectForKey:@(filter)];
    
    // "/v2/users/{userID}/shoppinglists/{listID}/empty"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
                                                       listID,
                                                       @"empty",
                                                       ]];
    [self.eta api:request
             type:ETARequestTypeDELETE
       parameters:(filterStr) ? @{ @"filter": filterStr } : nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           if (completionHandler)
           {
               completionHandler(error);
           }
       }];
}




#pragma mark -

#pragma mark - Permissions

- (BOOL) canReadShoppingLists
{
    NSString* userID = self.userID;
    if (userID)
        return [self.eta allowsPermission:[NSString stringWithFormat:@"api.users.%@.read",userID]];
    else
        return YES;
}
- (BOOL) canWriteShoppingLists
{
    NSString* userID = self.userID;
    if (userID)
        return [self.eta allowsPermission:[NSString stringWithFormat:@"api.users.%@.update",userID]];
    else
        return YES;
}



#pragma mark - Utilities

+ (NSString*) generateUUID
{
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuidStringRef];
    CFRelease(uuidStringRef);
    
    return [uuid lowercaseString];
}


@end
