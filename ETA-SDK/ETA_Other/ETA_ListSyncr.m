//
//  ETA_ListSyncr.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ListSyncr.h"

#import "ETA.h"

#import "MAKVONotificationCenter.h"
#import "EXTScope.h"

#import "ETA_ShoppingList.h"
#import "ETA_ShoppingList+FMDB.h"
#import "ETA_ShoppingListItem.h"
#import "ETA_ShoppingListItem+FMDB.h"
#import "ETA_ListShare.h"
#import "ETA_ListShare+FMDB.h"

#import "ETA_ListManager.h"

NSString* const ETA_ListSyncr_ChangeNotification_Lists = @"ETA_ListSyncr_ChangeNotification_Lists";
NSString* const ETA_ListSyncr_ChangeNotification_ListItems = @"ETA_ListSyncr_ChangeNotification_ListItems";
NSString* const ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey = @"modified";
NSString* const ETA_ListSyncr_ChangeNotificationInfo_AddedKey = @"added";
NSString* const ETA_ListSyncr_ChangeNotificationInfo_RemovedKey = @"removed";

@interface ETA_ListSyncr ()

@property (nonatomic, strong) ETA* eta;
@property (nonatomic, assign) id<ETA_ListSyncrDBHandlerProtocol> dbHandler;

@property (nonatomic, strong) NSTimer* pollingTimer;

@property (nonatomic, strong) NSOperationQueue* serverQ;

@property (atomic, assign) BOOL syncingInProgress;

@property (nonatomic, strong) NSMutableArray* modifiedItems;
@property (nonatomic, strong) NSMutableArray* removedItems;
@property (nonatomic, strong) NSMutableArray* addedItems;
@property (nonatomic, strong) NSMutableArray* modifiedLists;
@property (nonatomic, strong) NSMutableArray* removedLists;
@property (nonatomic, strong) NSMutableArray* addedLists;

@property (nonatomic, readwrite, assign) NSUInteger pullSyncCount;

@end


@implementation ETA_ListSyncr

static NSTimeInterval kETA_ListSyncr_DefaultPollInterval   = 6.0; // secs
static NSTimeInterval kETA_ListSyncr_SlowPollInterval      = 10.0; // secs



+ (instancetype) syncrWithETA:(ETA*)eta localDBQueryHandler:(id<ETA_ListSyncrDBHandlerProtocol>)dbHandler

{
    ETA_ListSyncr* syncr = [[ETA_ListSyncr alloc] init];
    syncr.dbHandler = dbHandler;
    syncr.eta = eta;
    return syncr;
}


- (id)init
{
    if ((self = [super init]))
    {
        self.serverQ = [NSOperationQueue new];
        self.serverQ.name = @"ETA_ListSyncr_ServerQueue";
        self.serverQ.maxConcurrentOperationCount = 1;

        _pollRate = ETA_ListSyncr_PollRate_Default;
        self.pollingTimer = nil;
        
        self.verbose = NO;
        
        self.syncingInProgress = NO;
    }
    return self;
}
- (void) dealloc
{
    [self stopPollingServer];
    
    self.eta = nil;
    self.dbHandler = nil;
}


- (void) setEta:(ETA *)eta
{
    if (_eta == eta)
        return;
    
    NSString* userKeyPath = @"attachedUserID";
    [self stopObserving:_eta keyPath:userKeyPath];
    
    _eta = eta;
    
    [self observeTarget:_eta keyPath:userKeyPath options:NSKeyValueObservingOptionInitial block:^(MAKVONotification *notification) {
        self.pullSyncCount = 0;
        //TODO: do something with the user id... maybe stop polling if it's null?
//        [self log:@"Attached User changed! %@ ", _eta.attachedUserID];
    }];
}


#pragma mark - Polling

- (void) setPollRate:(ETA_ListSyncr_PollRate)pollRate
{
    if (_pollRate == pollRate)
        return;
    
    _pollRate = pollRate;
    
    if (pollRate == ETA_ListSyncr_PollRate_None)
        [self stopPollingServer];
    else
        [self restartPollingServer];
}

- (NSTimeInterval) pollIntervalForPollRate:(ETA_ListSyncr_PollRate)pollRate
{
    switch (pollRate)
    {
        case ETA_ListSyncr_PollRate_Slow:
            return kETA_ListSyncr_SlowPollInterval;
            break;
        case ETA_ListSyncr_PollRate_None:
            return 0;
            break;
        case ETA_ListSyncr_PollRate_Default:
        default:
            return kETA_ListSyncr_DefaultPollInterval;
            break;
    }
}

- (void) startPollingServer
{
    if (!self.isPolling && self.pollRate != ETA_ListSyncr_PollRate_None)
    {
        self.pollingTimer = [NSTimer timerWithTimeInterval:[self pollIntervalForPollRate:self.pollRate]
                                                    target:self
                                                  selector:@selector(pollingTimerEvent:)
                                                  userInfo:[@{@"pollCount": @(-1)} mutableCopy]
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


// poll event tick
- (void) pollingTimerEvent:(NSTimer*)timer
{
    NSMutableDictionary* userInfo = timer.userInfo;
    NSInteger pollCount = [userInfo[@"pollCount"] integerValue] + 1;

    BOOL checkAllLists = (pollCount % 3 == 0);
    [self performSync:checkAllLists completionHandler:^(BOOL success) {
        if (success)
            userInfo[@"pollCount"] = @(pollCount);
    }];
    
}

- (void) performSync:(BOOL)checkAllLists completionHandler:(void(^)(BOOL success))completionHandler
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        [self log:@"\n------------- Sync %@ Started! ---------------------", (checkAllLists) ? @"All" : @"Modified"];
        
        
        // if there are still items in the server Q, skip this poll cycle
        if (self.syncingInProgress)
        {
            [self log:@"Sync still in progress (%d operations in Q)", self.serverQ.operationCount];
            if (completionHandler) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    completionHandler(NO);
                });
            }
            return;
        }
        
        // check if the user has logged out - if so dont do any syncing
        NSString* userID = self.eta.attachedUserID;
        if (!userID)
        {
            [self log:@"No attached user to sync"];
            if (completionHandler) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    completionHandler(NO);
                });
            }
            return;
        }
        
        
        
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        self.syncingInProgress = YES;
        
        NSArray* pendingSyncStates = @[@(ETA_DBSyncState_ToBeSynced), @(ETA_DBSyncState_Syncing), @(ETA_DBSyncState_ToBeDeleted), @(ETA_DBSyncState_Deleting)];
        
        
        // get all local lists & items that need to be synced or deleted (for the current ETA user)
        NSArray* pendingLocalItems = [self localDB_getAllObjectsWithSyncStates:pendingSyncStates
                                                                       forUser:userID
                                                                         class:ETA_ShoppingListItem.class];
        
        for (ETA_ShoppingListItem* pendingItem in pendingLocalItems)
        {
            NSOperation* operation = nil;
            if (pendingItem.state == ETA_DBSyncState_ToBeSynced || pendingItem.state == ETA_DBSyncState_Syncing)
            {
                operation = [self syncToServerOperationForItem:pendingItem];
                [self log:@"Add SyncItemOperation(%@) prev:'%@'", pendingItem.name, pendingItem.prevItemID];
            }
            else if (pendingItem.state == ETA_DBSyncState_ToBeDeleted || pendingItem.state == ETA_DBSyncState_Deleting)
            {
                operation = [self deleteFromServerOperationForItem:pendingItem];
                [self log:@"Add DeleteItemOperation(%@)", pendingItem.name];
            }
            
            if (operation)
                [self.serverQ addOperation:operation];
        }
        
        
        NSArray* pendingLocalLists = [self localDB_getAllObjectsWithSyncStates:pendingSyncStates
                                                                       forUser:userID
                                                                         class:ETA_ShoppingList.class];
        for (ETA_ShoppingList* pendingList in pendingLocalLists)
        {
            NSOperation* operation = nil;
            if (pendingList.state == ETA_DBSyncState_ToBeSynced || pendingList.state == ETA_DBSyncState_Syncing)
            {
                operation = [self syncToServerOperationForList:pendingList];
//                [self log:@"Add SyncListOperation(%@)", pendingList.name];
            }
            else if (pendingList.state == ETA_DBSyncState_ToBeDeleted || pendingList.state == ETA_DBSyncState_Deleting)
            {
                operation = [self deleteFromServerOperationForList:pendingList];
//                [self log:@"Add DeleteListOperation(%@)", pendingList.name];
            }
            
            if (operation)
                [self.serverQ addOperation:operation];
        }
        
        
        NSArray* pendingLocalShares = [self localDB_getAllObjectsWithSyncStates:pendingSyncStates
                                                                            forUser:userID
                                                                            class:ETA_ListShare.class];
        for (ETA_ListShare* pendingShare in pendingLocalShares)
        {
            NSOperation* operation = nil;
            if (pendingShare.state == ETA_DBSyncState_ToBeSynced || pendingShare.state == ETA_DBSyncState_Syncing)
            {
                operation = [self syncToServerOperationForShare:pendingShare];
            }
            else if (pendingShare.state == ETA_DBSyncState_ToBeDeleted || pendingShare.state == ETA_DBSyncState_Deleting)
            {
                operation = [self deleteFromServerOperationForShare:pendingShare];
            }
            
            if (operation)
                [self.serverQ addOperation:operation];
        }
        
        
        // Get Server Changes
        if (checkAllLists)
        {
//            [self log:@"Add GetServerChanges_AllLists Operation"];
            [self.serverQ addOperation:[self getServerChangesOperation_AllLists]];
        }
        else
        {
//            [self log:@"Add GetServerChanges_ModifiedLists Operation"];
            [self.serverQ addOperation:[self getServerChangesOperation_ModifiedLists]];
        }
        
        [self log:@"Waiting for all operations to complete..."];
        [self.serverQ waitUntilAllOperationsAreFinished];
        
        self.pullSyncCount ++;
        
        NSMutableDictionary* itemsNotification = [NSMutableDictionary new];
        NSMutableDictionary* listsNotification = [NSMutableDictionary new];
        
        // try to remove the objects
        if (self.removedLists.count && [self localDB_deleteObjects:self.removedLists error:nil])
        {
            listsNotification[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey] = self.removedLists;
        }
        if (self.modifiedLists.count && [self localDB_updateObjects:self.modifiedLists error:nil])
        {
            listsNotification[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey] = self.modifiedLists;
        }
        if (self.addedLists.count && [self localDB_updateObjects:self.addedLists error:nil])
        {
            listsNotification[ETA_ListSyncr_ChangeNotificationInfo_AddedKey] = self.addedLists;
        }
        
        if (self.removedItems.count && [self localDB_deleteObjects:self.removedItems error:nil])
        {
            itemsNotification[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey] = self.removedItems;
        }
        if (self.modifiedItems.count && [self localDB_updateObjects:self.modifiedItems error:nil])
        {
            itemsNotification[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey] = self.modifiedItems;
        }
        if (self.addedItems.count && [self localDB_updateObjects:self.addedItems error:nil])
        {
            itemsNotification[ETA_ListSyncr_ChangeNotificationInfo_AddedKey] = self.addedItems;
        }
        
        
        // save any added/removed/modified objects and send notification
        [self log:@"Sync Complete (%.4fs). Items: %d added / %d removed / %d modified ... Lists: %d added / %d removed / %d modified", [NSDate timeIntervalSinceReferenceDate]-start, self.addedItems.count, self.removedItems.count, self.modifiedItems.count, self.addedLists.count, self.removedLists.count, self.modifiedLists.count];
        
        
        [self sendNotificationOfDifferences:listsNotification objClass:ETA_ShoppingList.class];
        [self sendNotificationOfDifferences:itemsNotification objClass:ETA_ShoppingListItem.class];
        
        
        self.addedItems = nil;
        self.removedItems = nil;
        self.modifiedItems = nil;
        self.addedLists = nil;
        self.removedLists = nil;
        self.modifiedLists = nil;
        
        if (completionHandler)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completionHandler(YES);
            });
        }
        
        self.syncingInProgress = NO;
    });
}

- (NSMutableArray*) addedItems
{
    if (!_addedItems)
        _addedItems = [NSMutableArray new];
    return _addedItems;
}
- (NSMutableArray*) addedLists
{
    if (!_addedLists)
        _addedLists = [NSMutableArray new];
    return _addedLists;
}

- (NSMutableArray*) modifiedItems
{
    if (!_modifiedItems)
        _modifiedItems = [NSMutableArray new];
    return _modifiedItems;
}
- (NSMutableArray*) modifiedLists
{
    if (!_modifiedLists)
        _modifiedLists = [NSMutableArray new];
    return _modifiedLists;
}

- (NSMutableArray*) removedItems
{
    if (!_removedItems)
        _removedItems = [NSMutableArray new];
    return _removedItems;
}
- (NSMutableArray*) removedLists
{
    if (!_removedLists)
        _removedLists = [NSMutableArray new];
    return _removedLists;
    
}


#pragma mark - Server Get Changes operation

- (NSOperation*) getServerChangesOperation_AllListItemsInList:(NSString*)listID
{
    @weakify(self);
    return [NSBlockOperation blockOperationWithBlock:^{
        @strongify(self);
        
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        NSString* userID = self.eta.attachedUserID;
        
        [self server_getAllListItemsInList:listID forUser:userID completion:^(NSArray *serverItems) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (serverItems)
                {
                    NSArray* orderedServerItems = [self localDB_sortListItemsByPrevItemID:serverItems];
                    NSString* prevItemID = kETA_ListManager_FirstPrevItemID;
                    for (ETA_ShoppingListItem* item in orderedServerItems)
                    {
                        if ([prevItemID isEqualToString:item.prevItemID] == NO)
                        {
                            item.prevItemID = prevItemID;
                            item.modified = [NSDate date];
                            item.state = ETA_DBSyncState_ToBeSynced;
                        }
                        prevItemID = item.uuid;
                    }
                    
                    NSArray* localItems = [self localDB_getAllListItemsInList:listID withSyncStates:@[@(ETA_DBSyncState_Synced), @(ETA_DBSyncState_Syncing), @(ETA_DBSyncState_ToBeSynced)]];
                    
                    NSDictionary* diffs = [self getDifferencesBetweenLocalObjects:localItems andServerObjects:serverItems mergeHandler:nil];
                    
                    NSArray* added = diffs[ETA_ListSyncr_ChangeNotificationInfo_AddedKey];
                    NSArray* removed = diffs[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey];
                    NSArray* modified = diffs[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey];
                    
                    [self.addedItems addObjectsFromArray:added];
                    [self.removedItems addObjectsFromArray:removed];
                    [self.modifiedItems addObjectsFromArray:modified];
                    
                    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
                    [self log:@"[GetServerChanges] Getting All Items (%.4fs): %d added / %d removed / %d modified", duration, added.count, removed.count, modified.count];
                }
                dispatch_semaphore_signal(sema);
            });
        }];
        
        
        // block until server request is completed
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);
    }];
}


// Ask the server for all the list
// if there is a valid response, get all the local lists
// get the differences between the local and server lists
// lists that are on the server but arent on the local will be added
// lists that arent on the server, but are on the local, and which arent in the process of being synced, will be removed, and all the items of each of those lists will be removed
// lists that have a newer modified on the server will be updated locally
- (NSOperation*) getServerChangesOperation_AllLists
{
    @weakify(self);
    return [NSBlockOperation blockOperationWithBlock:^{
        @strongify(self);
        
//        [self log:@"[GetServerChanges] Start Getting All Lists"];
        
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        NSString* userID = self.eta.attachedUserID;
        // completion called on main thread
        [self server_getAllListsForUser:userID completion:^(NSArray *serverLists) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (serverLists)
                {
                    NSArray* localLists = [self localDB_getAllObjectsWithSyncStates:@[@(ETA_DBSyncState_Synced), @(ETA_DBSyncState_Syncing), @(ETA_DBSyncState_ToBeSynced)]
                                                                            forUser:userID
                                                                              class:ETA_ShoppingList.class];
                    
                    NSDictionary* diffs = [self getDifferencesBetweenLocalObjects:localLists andServerObjects:serverLists mergeHandler:nil];
                    
                    
                    for (ETA_ShoppingList* list in serverLists)
                    {
                        NSArray* localSharesForList = [self localDB_getAllSharesInList:list.uuid];
                        NSError* err = nil;
                        [self localDB_deleteObjects:localSharesForList error:&err];
                        
                        [self localDB_updateObjects:list.shares error:&err];
                    }
                    
                    // remove locally, and remove all the items locally
                    NSArray* removed = diffs[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey];
                    if (removed.count)
                    {
                        [self.removedLists addObjectsFromArray:removed];
                        for (ETA_ShoppingList* removedList in removed)
                        {
                            NSArray* itemsToRemove = [self localDB_getAllListItemsInList:removedList.uuid withSyncStates:nil];
                            [self.removedItems addObjectsFromArray:itemsToRemove];
                            
                            
                            NSArray* localSharesForList = [self localDB_getAllSharesInList:removedList.uuid];
                            NSError* err = nil;
                            [self localDB_deleteObjects:localSharesForList error:&err];
                        }
                    }

                    
                    
                    // add locally
                    NSArray* added = diffs[ETA_ListSyncr_ChangeNotificationInfo_AddedKey];
                    if (added.count)
                    {
                        [self.addedLists addObjectsFromArray:added];
                        for (ETA_ShoppingList* addedList in added)
                        {
                            // tell the Q to get item changes from this modified list
                            [self.serverQ addOperation:[self getServerChangesOperation_AllListItemsInList:addedList.uuid]];
                        }
                    }
                    
                    
                    
                    // update locally
                    NSArray* modified = diffs[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey];
                    if (modified.count)
                    {
                        [self.modifiedLists addObjectsFromArray:modified];
                        for (ETA_ShoppingList* modifiedList in modified)
                        {
                            // tell the Q to get item changes from this modified list
                            [self.serverQ addOperation:[self getServerChangesOperation_AllListItemsInList:modifiedList.uuid]];
                        }
                    }
                    
                    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
                    [self log:@"[GetServerChanges] Getting All Lists (%.4fs): %d added / %d removed / %d modified", duration, added.count, removed.count, modified.count];
                    
                }
                
                
                dispatch_semaphore_signal(sema);
            });
        }];
        
        // block until server request is completed
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);
        
    }];
}


// Ask the server for the modified date of all the local lists
// if the modified date is newer than the local list, get the server's version of the list
// save the modified list locally, and send a 'modified' notification for all the lists
- (NSOperation*) getServerChangesOperation_ModifiedLists
{
    @weakify(self);
    return [NSBlockOperation blockOperationWithBlock:^{
        @strongify(self);
        
//        [self log:@"[GetServerChanges] Start Getting Modified Lists"];
        
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        NSString* userID = self.eta.attachedUserID;
        
        NSArray* localLists = [self localDB_getAllObjectsWithSyncStates:@[@(ETA_DBSyncState_Synced)] forUser:userID class:ETA_ShoppingList.class];
        
        __block NSUInteger remainingLists = localLists.count;
        __block NSUInteger modifiedListCount = 0;
        __block NSUInteger deletedListCount = 0;
        
        if (localLists.count)
        {
            for (ETA_ShoppingList* localList in localLists)
            {
                NSDate* localModifiedDate = localList.modified;
                NSString* listID = localList.uuid;
                
                // completion called on main thread
                [self server_getModifiedDateForList:listID forUser:userID completion:^(NSDate *serverModifiedDate) {
                    // the server's modified date is newer than the local list's modified date
                    if ([self isModifiedDate:serverModifiedDate newerThanModifiedDate:localModifiedDate])
                    {
                        // get the modified server list
                        [self server_getList:listID forUser:userID completion:^(ETA_ShoppingList *serverList, NSError* serverError) {
                            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                                
                                // couldnt find the list on the server
                                // check the error - it may be that it was deleted
                                if (!serverList && serverError.code == 1501)
                                {
                                    deletedListCount++;
                                    [self.removedLists addObject:localList];
                                    
                                    // remove all the items for this list
                                    NSArray* itemsToRemove = [self localDB_getAllListItemsInList:listID withSyncStates:nil];
                                    [self.removedItems addObjectsFromArray:itemsToRemove];
                                    
                                    NSArray* localSharesForList = [self localDB_getAllSharesInList:listID];
                                    NSError* err = nil;
                                    [self localDB_deleteObjects:localSharesForList error:&err];
                                }
                                else if (serverList)
                                {
                                    if ([self localDB_hasObjectChangedSince:serverList] == NO)
                                    {
                                        modifiedListCount++;
                                        [self.modifiedLists addObject:serverList];
                                        
                                        // tell the Q to get item changes from this modified list
                                        [self.serverQ addOperation:[self getServerChangesOperation_AllListItemsInList:serverList.uuid]];
                                    }
                                    
                                    
                                    NSArray* localSharesForList = [self localDB_getAllSharesInList:listID];
                                    NSError* err = nil;
                                    [self localDB_deleteObjects:localSharesForList error:&err];
                                    
                                    [self localDB_updateObjects:serverList.shares error:&err];
                                }
                                
                                remainingLists--;
                                if (remainingLists == 0)
                                    dispatch_semaphore_signal(sema);
                            });
                        }];
                    }
                    else
                    {
                        remainingLists--;
                        if (remainingLists == 0)
                            dispatch_semaphore_signal(sema);
                    }
                }];
            }
            // block until server request is completed
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            dispatch_release(sema);
        }
        
         
        NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
        [self log:@"[GetServerChanges] Getting Modified Lists (%.4fs): %d modified / %d removed", duration, modifiedListCount, deletedListCount];
        
        
        
//        [self sendNotificationOfModified:changedLists
//                                   added:nil
//                                 removed:nil
//                          objectsOfClass:ETA_ShoppingList.class];
        
    }];
}






#pragma mark - Notification

- (void) sendNotificationOfDifferences:(NSDictionary*)diffs objClass:(Class)objClass
{
    NSUInteger removedCount = [diffs[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey] count];
    NSUInteger addedCount = [diffs[ETA_ListSyncr_ChangeNotificationInfo_AddedKey] count];
    NSUInteger modifiedCount = [diffs[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey] count];
    
    
    if (addedCount + removedCount + modifiedCount == 0)
        return;
    
    
    NSString* notificationName = nil;
    if ( objClass == ETA_ShoppingList.class )
    {
        notificationName = ETA_ListSyncr_ChangeNotification_Lists;
        
        [self log:@"[List Notification] %d added / %d removed / %d modified", addedCount, removedCount, modifiedCount];
    }
    else if ( objClass == ETA_ShoppingListItem.class )
    {
        notificationName = ETA_ListSyncr_ChangeNotification_ListItems;
        
        [self log:@"[Item Notification] %d added / %d removed / %d modified", addedCount, removedCount, modifiedCount];
    }
    
    if (!notificationName)
        return;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:diffs];
}


- (NSDictionary*) getDifferencesBetweenLocalObjects:(NSArray*)localObjects andServerObjects:(NSArray*)serverObjects mergeHandler:(ETA_ModelObject* (^)(ETA_ModelObject* serverObject, ETA_ModelObject* localObject))mergeHandler
{
    NSMutableArray* added = [NSMutableArray new]; // objects that were added to the server
    NSMutableArray* modified = [NSMutableArray new]; // objects that have changed on the server
    NSMutableArray* removed = [NSMutableArray new]; // objects that were removed from the server
    
    // make maps based on the objects uuids
    NSMutableDictionary* localObjectsByUUID = [NSMutableDictionary dictionaryWithCapacity:localObjects.count];
    for (ETA_DBSyncModelObject* obj in localObjects)
    {
        [localObjectsByUUID setValue:obj forKey:obj.uuid];
        if (obj.state != ETA_DBSyncState_Syncing && obj.state != ETA_DBSyncState_ToBeSynced)
            [removed addObject:obj];
    }
    
    
    // for each item in the server list
    for (ETA_ModelObject* serverObj in serverObjects)
    {
        if (!serverObj.uuid)
        {
            [self log: @"GetDiffs - Got a server object without a UUID... should not happen! %@", serverObj];
            continue;
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
            
            ETA_ModelObject* mergedObj = nil;
            if (mergeHandler)
                mergedObj = mergeHandler([serverObj copy], [localObj copy]);
            if (!mergedObj)
                mergedObj = serverObj;
            
            if ([self isObject:mergedObj newerThanObject:localObj])
            {
                [modified addObject:mergedObj];
            }
        }
    }
    
    NSMutableDictionary* differencesDict = [NSMutableDictionary dictionaryWithCapacity:3];
    
    if (removed.count)
        differencesDict[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey] = removed;
    
    if (added.count)
        differencesDict[ETA_ListSyncr_ChangeNotificationInfo_AddedKey] = added;
    
    if (modified.count)
        differencesDict[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey] = modified;
    
    return differencesDict;
    
}






#pragma mark - Server operations

#pragma mark  Delete

- (NSOperation*) deleteFromServerOperationForItem:(ETA_ShoppingListItem*)item
{
    return [self deleteFromServerOperationForObject:item
                                      operationName:item.name
                                       requestBlock:^(ETA_RequestCompletionBlock completionHandler) {
                                           
                                           NSString* userID = item.syncUserID;
                                           NSString* listID = item.shoppingListID;
                                           NSString* itemID = item.uuid;
                                           
                                           NSDictionary* jsonDict = [item JSONDictionary];

                                           // "/v2/users/{userID}/shoppinglists/{listID}/items/{itemID}"
                                           NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                                                              userID,
                                                                                              ETA_API.shoppingLists,
                                                                                              listID,
                                                                                              ETA_API.shoppingListItems,
                                                                                              itemID ]];
                                           
                                           [self log:@"[DeleteItemOperation(%@)] - Sending Request '%@'", item.name, request];
                                           
                                           [self.eta api:request
                                                    type:ETARequestTypeDELETE
                                              parameters:jsonDict
                                                useCache:NO
                                              completion:completionHandler];
                                       }];
}

- (NSOperation*) deleteFromServerOperationForList:(ETA_ShoppingList*)list
{
    return [self deleteFromServerOperationForObject:list
                                      operationName:list.name
                                       requestBlock:^(ETA_RequestCompletionBlock completionHandler) {
                                           
                                           NSString* userID = list.syncUserID;
                                           NSString* listID = list.uuid;
                                           
                                           // "/v2/users/{userID}/shoppinglists/{listID}?modified={now}"
                                           NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                                                              userID,
                                                                                              ETA_API.shoppingLists,
                                                                                              listID]];
                                           
                                           [self log:@"[DeleteListOperation(%@)] - Sending Request '%@'", list.name, request];
                                           
                                           [self.eta api:request
                                                    type:ETARequestTypeDELETE
                                              parameters:@{@"modified":[ETA_API.dateFormatter stringFromDate:list.modified]}
                                                useCache:NO
                                              completion:completionHandler];
                                       }];
}

- (NSOperation*) deleteFromServerOperationForObject:(ETA_DBSyncModelObject*)obj operationName:(NSString*)opName requestBlock:(void (^)(ETA_RequestCompletionBlock))requestBlock
{
    @weakify(self);
    NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:^{
        @strongify(self);
        
        [self log:@"[DeleteObjOperation(%@)] started", opName];
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        NSString* userID = obj.syncUserID;
        
        
        // check if the sdk has changed users while the item was waiting
        if ([self.eta.attachedUserID isEqualToString:userID] == NO)
        {
            [self log:@"[DeleteObjOperation(%@)] attachedUser different to Object being deleted... skip it", opName];
            return;
        }
        
        // check the items modified date - has it changed since we first got the item
        if ([self localDB_hasObjectChangedSince:obj])
        {
            [self log:@"[DeleteObjOperation(%@)] Item modified since being added to queue... skip this item", opName];
            return;
        }
        
        // mark the item as being synced
        obj.state = ETA_DBSyncState_Deleting;
        NSError* err;
        if (![self localDB_updateObjects:@[obj] error:&err])
        {
            [self log:@"[DeleteObjOperation(%@)] Unable to mark Object as Deleting - abort", opName];
            return;
        }
        
        
        if (requestBlock)
        {
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            // do the talking to the server, which will call the completion handler when done
            requestBlock(^void(id response, NSError *requestError, BOOL fromCache) {
                
                // if the requestError is that the item doesnt exist on the server then consider that a success!
                if (requestError && requestError.code != 1501)
                {
                    //TODO: if serious error mark item as Failed so we dont try it again?
                    obj.state = ETA_DBSyncState_ToBeDeleted;
                    
                    [self log:@"[DeleteObjOperation(%@)] Request Error %d:'%@'", opName, requestError.code, requestError.localizedDescription];
                    
                    NSError* updateErr = nil;
                    if (![self localDB_updateObjects:@[obj] error:&updateErr])
                    {
                        [self log:@"[DeleteObjOperation(%@)] ALSO Failed to mark as 'ToBeDeleted' %d:'%@'", opName, updateErr.code, updateErr.localizedDescription];
                    }
                }
                else
                {
                    // try to remove from the local DB
                    NSError* deleteErr;
                    if (![self localDB_deleteObjects:@[obj] error:&deleteErr])
                    {
                        [self log:@"[DeleteObjOperation(%@)] Completed - Unable to remove from localDB %d:'%@'", opName, deleteErr.code, deleteErr.localizedDescription];
                    }
                }
                dispatch_semaphore_signal(sema);
            });
            
            // block until server request is completed
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            dispatch_release(sema);
        }
        else
        {
            [self log:@"[DeleteObjOperation(%@)] No Request Block!", opName];
        }
        
        NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate]-start;
        
        [self log:@"[DeleteObjOperation(%@)] finished (%.4fs)", opName, duration];
    }];
    return op;
}


- (NSOperation*) deleteFromServerOperationForShare:(ETA_ListShare*)share
{
    @weakify(self);
    NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:^{
        @strongify(self);
        
        [self log:@"[DeleteShareOperation(%@-%@)] started", share.userEmail, share.listUUID];
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        NSString* userID = share.syncUserID;
        NSString* listID = share.listUUID;
        NSString* userEmail = share.userEmail;
        
        // check if the sdk has changed users while the item was waiting
        if ([self.eta.attachedUserID isEqualToString:userID] == NO)
        {
            [self log:@"[DeleteShareOperation(%@-%@)] attachedUser different to Share being deleted... skip it", share.userEmail, share.listUUID];
            return;
        }
        
        // mark the item as being synced
        share.state = ETA_DBSyncState_Deleting;
        NSError* err;
        if (![self localDB_updateObjects:@[share] error:&err])
        {
            [self log:@"[DeleteShareOperation(%@-%@)] Unable to mark Share as Deleting - abort", share.userEmail, share.listUUID];
            return;
        }
        
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        
        // "/v2/users/{userID}/shoppinglists/{listID}/shares/{userEmail}"
        NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                           userID,
                                                           ETA_API.shoppingLists,
                                                           listID,
                                                           @"shares",
                                                           userEmail]];
        
        [self log:@"[DeleteShareOperation(%@-%@)] - Sending Request '%@'", share.userEmail, share.listUUID, request];
        
        [self.eta api:request
                 type:ETARequestTypeDELETE
           parameters:nil
             useCache:NO
           completion:^(id response, NSError *requestError, BOOL fromCache) {
               
               if (requestError)
               {
                   //TODO: if serious error mark item as Failed so we dont try it again?
                   share.state = ETA_DBSyncState_ToBeDeleted;
                   [self log:@"[DeleteShareOperation(%@-%@)] Request Error %d:'%@'", share.userEmail, share.listUUID, requestError.code, requestError.localizedDescription];
                   
                   NSError* updateErr = nil;
                   if (![self localDB_updateObjects:@[share] error:&updateErr])
                   {
                       [self log:@"[DeleteShareOperation(%@-%@)] ALSO Failed to mark as 'ToBeDeleted' %d:'%@'", share.userEmail, share.listUUID, updateErr.code, updateErr.localizedDescription];
                   }
               }
               else
               {
                   // try to remove from the local DB
                   NSError* deleteErr;
                   if (![self localDB_deleteObjects:@[share] error:&deleteErr])
                   {
                       [self log:@"[DeleteShareOperation(%@-%@)] Completed - Unable to remove from localDB %d:'%@'", share.userEmail, share.listUUID, deleteErr.code, deleteErr.localizedDescription];
                   }
               }
               dispatch_semaphore_signal(sema);
           }];
        
        
        // block until server request is completed
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);
        
        NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate]-start;
        
        [self log:@"[DeleteShareOperation(%@)] finished (%.4fs)", share.userEmail, share.listUUID, duration];
    }];
    return op;
}




#pragma mark Sync

// the action that will sync an item to the server
- (NSOperation*) syncToServerOperationForItem:(ETA_ShoppingListItem*)item
{
    return [self syncToServerOperationForObject:item
                                  operationName:item.name
                                   requestBlock:^(ETA_RequestCompletionBlock completionHandler) {
                                       
                                       NSString* itemID = item.uuid;
                                       NSString* userID = item.syncUserID;
                                       NSString* listID = item.shoppingListID;
                                       
                                       NSDictionary* jsonDict = [item JSONDictionary];
                                       
                                       // "/v2/users/{userID}/shoppinglists/{listID}/items/{itemID}"
                                       NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                                                          userID,
                                                                                          ETA_API.shoppingLists,
                                                                                          listID,
                                                                                          ETA_API.shoppingListItems,
                                                                                          itemID
                                                                                          ]];
                                       
                                       [self log:@"[SyncItemOperation(%@)] - Sending Request '%@'", item.name, request];
                                       
                                       // send request to server. Will not block operation
                                       [self.eta api:request
                                                type:ETARequestTypePUT
                                          parameters:jsonDict
                                            useCache:NO
                                          completion:completionHandler];
                                   }];
}


// the action that will sync an item to the server
- (NSOperation*) syncToServerOperationForList:(ETA_ShoppingList*)list
{
    return [self syncToServerOperationForObject:list
                                  operationName:list.name
                                   requestBlock:^(ETA_RequestCompletionBlock completionHandler) {
                                       
                                       NSString* userID = list.syncUserID;
                                       NSString* listID = list.uuid;
                                       
                                       NSDictionary* jsonDict = [list JSONDictionary];
                                       
                                       // "/v2/users/{userID}/shoppinglists/{listID}"
                                       NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                                                          userID,
                                                                                          ETA_API.shoppingLists,
                                                                                          listID]];
                                       
                                       [self log:@"[SyncListOperation(%@)] - Sending Request '%@'", list.name, request];
                                       
                                       // send request to server. Will not block operation
                                       [self.eta api:request
                                                type:ETARequestTypePUT
                                          parameters:jsonDict
                                            useCache:NO
                                          completion:completionHandler];
                                   }];
}

// the action that will sync a share to the server
- (NSOperation*) syncToServerOperationForShare:(ETA_ListShare*)share
{
    @weakify(self);
    NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:^{
        @strongify(self);
        [self log:@"[SyncShareOperation(%@-%@)] started", share.userEmail, share.listUUID];
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        NSString* userID = share.syncUserID;
        
        
        // check if the sdk has changed users while the item was waiting
        if ([self.eta.attachedUserID isEqualToString:userID] == NO)
        {
            [self log:@"[SyncShareOperation(%@-%@)] attachedUser different to share being synced... skip it", share.userEmail, share.listUUID];
            return;
        }
        
        
        // mark the item as being synced
        share.state = ETA_DBSyncState_Syncing;
        NSError* err;
        if (![self localDB_updateObjects:@[share] error:&err])
        {
            [self log:@"[SyncShareOperation(%@-%@)] Unable to mark Share as Syncing - abort", share.userEmail, share.listUUID];
            return;
        }
        
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        NSString* listID = share.listUUID;
        
        NSDictionary* jsonDict = [share JSONDictionary];
        
        // "/v2/users/{userID}/shoppinglists/{listID}/shares/{email}"
        NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                           userID,
                                                           ETA_API.shoppingLists,
                                                           listID,
                                                           @"shares",
                                                           share.userEmail]];
        
        [self log:@"[SyncShareOperation(%@-%@)] - Sending Request '%@'", share.userEmail, share.listUUID, request];
            
        // send request to server. Will not block operation
        [self.eta api:request
                 type:ETARequestTypePUT
           parameters:@{@"access": jsonDict[@"access"],
                        @"accept_url": jsonDict[@"acceptURL"],
                        }
             useCache:NO
           completion:^(id response, NSError *requestError, BOOL fromCache) {
               
               if (requestError)
               {
                   //TODO: if serious error mark item as Failed so we dont try it again?
                   share.state = ETA_DBSyncState_ToBeSynced;
                   [self log:@"[SyncShareOperation(%@-%@)] Request Error %d:'%@'", share.userEmail, share.listUUID, requestError.code, requestError.localizedDescription];
                   
                   NSError* updateErr = nil;
                   if (![self localDB_updateObjects:@[share] error:&updateErr])
                   {
                       [self log:@"[SyncShareOperation(%@-%@)] ALSO Failed to mark as 'ToBeSynced' %d:'%@'", share.userEmail, share.listUUID, updateErr.code, updateErr.localizedDescription];
                   }
               }
               else
               {
                   share.state = ETA_DBSyncState_Synced;
                   
                   NSError* updateErr = nil;
                   if (![self localDB_updateObjects:@[share] error:&updateErr])
                   {
                       [self log:@"[SyncShareOperation(%@-%@)] Completed - Failed to mark as 'Synced' %d:'%@'", share.userEmail, share.listUUID, updateErr.code, updateErr.localizedDescription];
                   }
                   else
                   {
                       [self log:@"[SyncShareOperation(%@-%@)] Completed - Marked as 'Synced'", share.userEmail, share.listUUID];
                   }
               }
               
               dispatch_semaphore_signal(sema);
           }];
        
        // block until server request is completed
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);
        
        NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate]-start;
        
        [self log:@"[SyncShareOperation(%@-%@)] finished (%.4fs)", share.userEmail, share.listUUID, duration];
    }];
    return op;

}


- (NSOperation*) syncToServerOperationForObject:(ETA_DBSyncModelObject*)obj operationName:(NSString*)opName requestBlock:(void (^)(ETA_RequestCompletionBlock))requestBlock
{
    @weakify(self);
    NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:^{
        @strongify(self);
        
        [self log:@"[SyncObjOperation(%@)] started", opName];
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        NSString* userID = obj.syncUserID;
        
        
        // check if the sdk has changed users while the item was waiting
        if ([self.eta.attachedUserID isEqualToString:userID] == NO)
        {
            [self log:@"[SyncObjOperation(%@)] attachedUser different to Object being synced... skip it", opName];
            return;
        }
        
        // check the items modified date - has it changed since we first got the item
        if ([self localDB_hasObjectChangedSince:obj])
        {
            [self log:@"[SyncObjOperation(%@)] Item modified since being added to queue... skip this item", opName];
            return;
        }
        
        // mark the item as being synced
        obj.state = ETA_DBSyncState_Syncing;
        NSError* err;
        if (![self localDB_updateObjects:@[obj] error:&err])
        {
            [self log:@"[SyncObjOperation(%@)] Unable to mark Object as Syncing - abort", opName];
            return;
        }
        
        if (requestBlock)
        {
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            // do the talking to the server, which will call the completion handler when done
            requestBlock(^void(id response, NSError *requestError, BOOL fromCache) {
                
                // check if item was modified while we were sending the request, so its state may have changed... if so dont mark as synced
                if ([self localDB_hasObjectChangedSince:obj] == NO)
                {
                    
                    if (requestError)
                    {
                        //TODO: if serious error mark item as Failed so we dont try it again?
                        obj.state = ETA_DBSyncState_ToBeSynced;
                        [self log:@"[SyncObjOperation(%@)] Request Error %d:'%@'", opName, requestError.code, requestError.localizedDescription];
                        
                        NSError* updateErr = nil;
                        if (![self localDB_updateObjects:@[obj] error:&updateErr])
                        {
                             [self log:@"[SyncObjOperation(%@)] ALSO Failed to mark as 'ToBeSynced' %d:'%@'", opName,updateErr.code, updateErr.localizedDescription];
                        }
                    }
                    else
                    {
                        obj.state = ETA_DBSyncState_Synced;
                        
                        NSError* updateErr = nil;
                        if (![self localDB_updateObjects:@[obj] error:&updateErr])
                        {
                            [self log:@"[SyncObjOperation(%@)] Completed - Failed to mark as 'Synced' %d:'%@'", opName, updateErr.code, updateErr.localizedDescription];
                        }
                        else
                        {
                            [self log:@"[SyncObjOperation(%@)] Completed - Marked as 'Synced'", opName];
                        }
                    }
                    
                }
                else
                {
                    [self log:@"[SyncObjOperation(%@)] Item modified while sync request was being sent - dont mark as 'Synced'", opName];
                }
                dispatch_semaphore_signal(sema);
            });
            
            // block until server request is completed
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            dispatch_release(sema);
        }
        else
        {
            [self log:@"[SyncObjOperation(%@)] No Request Block!", opName];
        }
        
        NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate]-start;
        
        [self log:@"[SyncObjOperation(%@)] finished (%.4fs)", opName, duration];
    }];
    return op;
}










#pragma mark - Server Getters

- (void) server_getSharesForList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(NSArray* shares))completionHandler
{
    if (!completionHandler)
        return;
    
    if (!userID)
    {
        completionHandler(nil);
        return;
    }
    
    //   "/v2/users/{userID}/shoppinglists/{listID}/shares"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                                                       userID,
                                                       ETA_API.shoppingLists,
                                                       listID,
                                                       @"shares"]];
    
    [self.eta api:request
             type:ETARequestTypeGET
       parameters:nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           NSMutableArray* shares = nil;
           if (!error)
           {
               if ([response isKindOfClass:[NSArray class]] == NO)
                   response = @[response];
               
               shares = [NSMutableArray new];
               for (id obj in response)
               {
                   ETA_ListShare* share = [ETA_ListShare objectFromJSONDictionary:obj];
                   if (share)
                   {
                       share.syncUserID = userID;
                       share.state = ETA_DBSyncState_Synced;
                       [shares addObject:share];
                   }
               }
           }
           else
           {
               [self log:@"server_getAllSharesForListForUser: failed %d:'%@'", error.code, error.localizedDescription];
           }
           completionHandler(shares);
       }];
}


#pragma mark Lists

- (void) server_getList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(ETA_ShoppingList* list, NSError* serverError))completionHandler
{
    if (!completionHandler)
        return;
    
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
           ETA_ShoppingList* list = nil;
           
           if (!error)
           {
               list = [ETA_ShoppingList objectFromJSONDictionary:response];
               list.syncUserID = userID;
               list.state = ETA_DBSyncState_Synced;
               
               for (ETA_ListShare* share in list.shares) {
                   share.syncUserID = userID;
                   share.state = ETA_DBSyncState_Synced;
               }
           }
           else
           {
               [self log:@"server_getList:forUser: failed %d:'%@'", error.code, error.localizedDescription];
           }
           completionHandler(list, error);
       }];
}


- (void) server_getAllListsForUser:(NSString*)userID completion:(void (^)(NSArray* lists))completionHandler
{
    if (!completionHandler)
        return;
    
    if (!userID)
    {
        completionHandler(nil);
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
               
               lists = [NSMutableArray new];
               for (id obj in response)
               {
                   ETA_ShoppingList* list = [ETA_ShoppingList objectFromJSONDictionary:obj];
                   if (list)
                   {
                       list.syncUserID = userID;
                       list.state = ETA_DBSyncState_Synced;
                       
                       for (ETA_ListShare* share in list.shares) {
                           share.syncUserID = userID;
                           share.state = ETA_DBSyncState_Synced;
                       }
                       [lists addObject:list];
                   }
               }
           }
           else
           {
               [self log:@"server_getAllListsForUser: failed %d:'%@'", error.code, error.localizedDescription];
           }
           completionHandler(lists);
       }];
}

- (void) server_getModifiedDateForList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(NSDate* modifiedDate))completionHandler
{
    if (!completionHandler)
        return;
    
    if (!userID || !listID)
    {
        completionHandler(nil);
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
           else
           {
               [self log:@"server_getModifiedDateForList:forUser: failed %d:'%@'", error.code, error.localizedDescription];
           }
           
           completionHandler(modified);
       }];
}

- (void) server_getAllListItemsInList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(NSArray* items))completionHandler
{
    if (!completionHandler)
        return;
    
    if (!userID || !listID)
    {
        completionHandler(nil);
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
                   ETA_ShoppingListItem* item = [ETA_ShoppingListItem objectFromJSONDictionary:obj];
                   if (item)
                   {
                       // ergh - server shopping_list_id is the old API id... make sure we use the new one
                       item.shoppingListID = listID;
                       item.syncUserID = userID;
                       item.state = ETA_DBSyncState_Synced;
                       [items addObject:item];
                   }
               }
           }
           else
           {
               [self log:@"server_getAllItemsInList:forUser: failed %d:'%@'", error.code, error.localizedDescription];
           }
           
           completionHandler(items);
       }];
}









#pragma mark - Local DB Methods


- (BOOL) localDB_hasObjectChangedSince:(ETA_DBSyncModelObject*)obj
{
    // check the items modified date - has it changed since we first got the item
    ETA_DBSyncModelObject* currentObj = [self localDB_getObjectWithUUID:obj.uuid class:obj.class];
    
    return [self isObject:currentObj newerThanObject:obj];
}

- (BOOL) localDB_deleteObjects:(NSArray*)objects error:(NSError * __autoreleasing *)error
{
    if (!objects.count)
        return YES;
    return [self.dbHandler deleteDBObjects:objects error:error];
}

- (BOOL) localDB_updateObjects:(NSArray*)objects error:(NSError * __autoreleasing *)error
{
    if (!objects.count)
        return YES;
    
    return [self.dbHandler updateDBObjects:objects error:error];
}

- (ETA_DBSyncModelObject*) localDB_getObjectWithUUID:(NSString*)objUUID class:(Class)objClass
{
    return [self.dbHandler getDBObjectWithUUID:objUUID objClass:objClass];
}

- (NSArray*) localDB_getAllObjectsWithSyncStates:(NSArray*)syncStates forUser:(id)userID class:(Class)objClass
{
    return [self.dbHandler getAllDBObjectsWithSyncStates:syncStates forUser:userID objClass:objClass];
}

- (NSArray*) localDB_getAllListItemsInList:(NSString*)listID withSyncStates:(NSArray*)syncStates
{
    return [self.dbHandler getAllDBListItemsInList:listID withSyncStates:syncStates];
}
- (NSArray*) localDB_getAllSharesInList:(NSString*)listID
{
    return [self.dbHandler getAllDBSharesInList:listID];
}

- (NSArray*) localDB_sortListItemsByPrevItemID:(NSArray*)items
{
    return [self.dbHandler sortListItemsByPrevItemID:items];
}


     
#pragma mark - Utilities
- (BOOL) isModifiedDate:(NSDate*)modifiedDateA newerThanModifiedDate:(NSDate*)modifiedDateB
{
    NSComparisonResult compare = NSOrderedSame;
    if (modifiedDateA != modifiedDateB)
    {
        // A has no date, while B does, so assume B is newer
        if (!modifiedDateA)
            compare = NSOrderedAscending;
        // B has no date, but A does. odd situation, but assume A is newer
        else if (!modifiedDateB)
            compare = NSOrderedDescending;
        // both A and B have a date - compare them
        else
            compare = [modifiedDateA compare:modifiedDateB];
    }
    
    // A version is newer
    if (compare == NSOrderedDescending)
        return YES;
    else
        return NO;
}
- (BOOL) isObject:(id)objA newerThanObject:(id)objB
{
    return [self isModifiedDate:[objA valueForKey:@"modified"] newerThanModifiedDate:[objB valueForKey:@"modified"]];
}


- (void) log:(NSString*)format, ...
{
    if (!self.verbose)
        return;
    
    va_list args;
    va_start(args, format);
    NSString* msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"[ETA_ListSyncr] %@", msg);
}




@end