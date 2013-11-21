//
//  ETA_ShoppingListManager.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ShoppingListManager.h"
#import "ETA.h"
#import "ETA_APIClient.h"

#import "ETA_User.h"
#import "ETA_Session.h"

#import "ETA_ShoppingList.h"
#import "ETA_ShoppingListItem.h"

#import "ETA_ShoppingList+FMDB.h"
#import "ETA_ShoppingListItem+FMDB.h"

#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
#import "EXTScope.h"

NSString* const ETA_ShoppingListManager_ListsChangedNotification = @"ETA_ShoppingListManager_ListsChangedNotification";
NSString* const ETA_ShoppingListManager_ItemsChangedNotification = @"ETA_ShoppingListManager_ItemsChangedNotification";
NSString* const ETA_ShoppingListManager_ItemsUpdatedNotification = @"ETA_ShoppingListManager_ItemsUpdatedNotification";
NSString* const ETA_ShoppingListManager_ItemsRemovedNotification = @"ETA_ShoppingListManager_ItemsRemovedNotification";
NSString* const ETA_ShoppingListManager_ItemsAddedNotification = @"ETA_ShoppingListManager_ItemsAddedNotification";

NSString* const kETA_ShoppingListManager_FirstPrevItemID = @"<first>";

NSTimeInterval const kETA_ShoppingListManager_FastPollInterval      = 2.0; // secs
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

@property (nonatomic, readwrite, strong) NSOperationQueue* serverQ;

@end




@implementation ETA_ShoppingListManager

// increment this number will cause the table to be dropped and rebuilt
static NSUInteger kLocalDBVersion = 1;

@synthesize userID = _userID;

+ (instancetype) sharedManager
{
    if (!ETA.SDK)
        return nil;
    
    static ETA_ShoppingListManager* sharedShoppingListManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedShoppingListManager = [self managerWithETA:ETA.SDK];
    });
    return sharedShoppingListManager;
}

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
        
        [self log:@"LocalDB: '%@'", localDBPath];
        
        self.dbQ = [FMDatabaseQueue databaseQueueWithPath:localDBPath];
        [self localDBCreateTables];
        
        
        self.serverQ = [NSOperationQueue new];
        self.serverQ.name = @"ETA_ShoppingListManager_ServerQueue";
        self.serverQ.maxConcurrentOperationCount = 1;
        
        
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
    self.serverQ = nil;    
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
    
    
//    [_eta removeObserver:self forKeyPath:@"client.session"];
    [_eta removeObserver:self forKeyPath:@"attachedUserID"];
    
    _eta = eta;
    
    [_eta addObserver:self forKeyPath:@"attachedUserID" options:0 context:NULL];
    
    self.userID = _eta.attachedUserID;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"attachedUserID"])
    {
        if (_eta.attachedUserID != self.userID && [_eta.attachedUserID isEqualToString:self.userID] == NO)
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
- (void) createWishList:(NSString*)name
                 completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler
{
    NSString* uuid = [[self class] generateUUID];
    
    ETA_ShoppingList* wishList = [ETA_ShoppingList wishListWithUUID:uuid
                                                               name:name
                                                       modifiedDate:nil
                                                             access:ETA_ShoppingList_Access_Private];
    
    [self addShoppingList:wishList completion:completionHandler];
}
// create and add a totally new shopping list
- (void) createShoppingList:(NSString*)name
                 completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler
{
    NSString* uuid = [[self class] generateUUID];

    ETA_ShoppingList* shoppingList = [ETA_ShoppingList shoppingListWithUUID:uuid
                                                                       name:name
                                                               modifiedDate:nil
                                                                     access:ETA_ShoppingList_Access_Private];
    
    [self addShoppingList:shoppingList completion:completionHandler];
}

// add the specified shopping list
- (void) addShoppingList:(ETA_ShoppingList*)list
              completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler
{
    [self updateShoppingList:list completion:completionHandler];
}

- (void) updateShoppingList:(ETA_ShoppingList*)list
                 completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler
{    
    NSError* err = nil;
    if (!list.uuid)
        err = [NSError errorWithDomain:@"" code:0 userInfo:nil];

    if (!err)
    {
        NSString* userID = self.userID;
        
        BOOL isAdding = ([self localDBContainsShoppingListWithID:list.uuid userID:userID] == NO);
        
        list.modified = [NSDate date];
        
        // we are logged in - try to sending to the server
        if (userID)
        {
            [self syncObjectToServer:list remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID completion:^(ETA_DBSyncModelObject* syncedObject, NSError *error) {
                if (completionHandler)
                    completionHandler((ETA_ShoppingList*)syncedObject, error, YES);
            }];
        }
        // no user - simply send the list to the local db
        else
        {
            [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:list userID:userID];
        }
        
        // send notifications
        if (isAdding)
            [self sendNotificationForAdded:@[list] removed:nil modified:nil type:ETA_ShoppingList.class];
        else
            [self sendNotificationForAdded:nil removed:nil modified:@[list] type:ETA_ShoppingList.class];
    }
    
    // send local completion handler
    if (completionHandler)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(list, err, NO);
        });
    }
    
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

- (void) createShoppingListItem:(NSString *)name offerID:(NSString*)offerID inList:(NSString*)listID completion:(void (^)(ETA_ShoppingListItem *, NSError *, BOOL))completionHandler
{
    if (!name || !listID)
    {
        if (completionHandler)
        {
            //TODO: NSError when no name or listID
            completionHandler(nil, nil, NO);
        }
        return;
    }
    
    ETA_ShoppingListItem* item = [[ETA_ShoppingListItem alloc] initWithDictionary:@{@"uuid":[[self class] generateUUID],
                                                                                    @"name": name,
                                                                                    @"shoppingListID": listID,
                                                                                    }
                                                                            error:nil];
    item.count = 1;
    item.creator = self.eta.attachedUser.email;
    item.prevItemID = kETA_ShoppingListManager_FirstPrevItemID;
    item.offerID = offerID;
    
    [self addShoppingListItem:item completion:completionHandler];
}

- (void) addShoppingListItem:(ETA_ShoppingListItem *)item completion:(void (^)(ETA_ShoppingListItem *, NSError *, BOOL))completionHandler
{
    [self updateShoppingListItem:item completion:completionHandler];
}


- (void) updateShoppingListItem:(ETA_ShoppingListItem*)item completion:(void (^)(ETA_ShoppingListItem *, NSError *, BOOL))completionHandler
{
    [self updateShoppingListItem:item userID:self.userID completion:completionHandler];
}

- (void) sendItemsUpdatedNotification:(NSArray*)items
{
    if (!items.count)
        return;
    
    @synchronized(self)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_ShoppingListManager_ItemsUpdatedNotification
                                                            object:self
                                                          userInfo:@{@"items":items}];
    }
}
- (void) sendItemsRemovedNotification:(NSArray*)items
{
    if (!items.count)
        return;
    
    @synchronized(self)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_ShoppingListManager_ItemsRemovedNotification
                                                            object:self
                                                          userInfo:@{@"items":items}];
    }
}
- (void) sendItemsAddedNotification:(NSArray*)items
{
    if (!items.count)
        return;
    
    @synchronized(self)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:ETA_ShoppingListManager_ItemsAddedNotification
                                                            object:self
                                                          userInfo:@{@"items":items}];
    }
}


- (void) updateShoppingListItem:(ETA_ShoppingListItem*)item userID:(NSString*)userID completion:(void (^)(ETA_ShoppingListItem *, NSError *, BOOL))completionHandler
{
    if (!item.uuid)
    {
        if (completionHandler)
        {
            //TODO: NSError when no UUID
            
            completionHandler(nil, nil, NO);
        }
        return;
    }
    
    ETA_ShoppingListItem* existingItem = [self localDBGetShoppingListItem:item.uuid userID:userID];
    BOOL isAdding = !existingItem;
    
    item.modified = [NSDate date];
    
    // we are logged in - try to sending to the server
    if (userID)
    {
//        if (nextItem)
//            [self syncObjectToServer:nextItem remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID completion:nil];
        
        [self syncObjectToServer:item remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID completion:^(ETA_DBSyncModelObject *syncedObj, NSError *error) {
            if (completionHandler)
                completionHandler((ETA_ShoppingListItem*)syncedObj, error, YES);
        }];
    }
    // no user - simply send the item to the local db
    else
    {
//        if (nextItem)
//            [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:nextItem userID:userID];
        
        [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:item userID:userID];
    }
    
    if (completionHandler)
        completionHandler(item, nil, NO);
    
    
    
    NSString* oldPrevID = existingItem.prevItemID;
    NSString* newPrevID = item.prevItemID;
    
    // finally do an update of the next item, if needed
    NSString* nextItemsOldPrevItemID = nil;
    NSString* nextItemsNewPrevItemID = nil;
    if (isAdding)
    {
        nextItemsOldPrevItemID = item.prevItemID;
        nextItemsNewPrevItemID = item.uuid;
    }
    // isMoving
    else if ([oldPrevID isEqualToString:newPrevID] == NO && oldPrevID != newPrevID)
    {
        // next item needs to change
        ETA_ShoppingListItem* newPrevItem = [self localDBGetShoppingListItem:newPrevID userID:userID];
        ETA_ShoppingListItem* oldPrevItem = [self localDBGetShoppingListItem:oldPrevID userID:userID];
        
        if ([newPrevItem.prevItemID isEqualToString:oldPrevID] == NO && newPrevItem.prevItemID != oldPrevID &&
            [oldPrevItem.prevItemID isEqualToString:newPrevID] == NO && oldPrevItem.prevItemID != newPrevID )
        {
            
            nextItemsOldPrevItemID = item.uuid;
            nextItemsNewPrevItemID = item.prevItemID;
        }
    }
    
    if (nextItemsOldPrevItemID)
    {
        // update the item that was in this items place
        ETA_ShoppingListItem* nextItem = [self localDBGetShoppingListItemWithPreviousItemID:nextItemsOldPrevItemID inList:item.shoppingListID userID:userID];
        
        if (nextItem && [nextItem.prevItemID isEqualToString:nextItemsNewPrevItemID] == NO && nextItem.prevItemID != nextItemsNewPrevItemID)
        {
            nextItem.prevItemID = nextItemsNewPrevItemID;
            
            [self updateShoppingListItem:nextItem userID:userID completion:^(ETA_ShoppingListItem *updatedNextItem, NSError *error, BOOL fromServer) {
                if (!fromServer)
                {
                    [self sendItemsUpdatedNotification:@[updatedNextItem]];
                }
            }];
        }
    }

//
//    if (isAdding)
//        [self sendNotificationForAdded:@[item] removed:nil modified:nil type:ETA_ShoppingListItem.class];
//    else
//        [self sendNotificationForAdded:nil removed:nil modified:@[item] type:ETA_ShoppingListItem.class];
    
}

- (void) removeShoppingListItem:(ETA_ShoppingListItem *)item completion:(void (^)(ETA_ShoppingListItem *, NSError *))completionHandler
{
    if (!item.uuid)
    {
        if (completionHandler)
        {
            //TODO: Error if no item UUID
            completionHandler(nil, nil);
        }
        return;
    }
    
    // are we adding to the local or server list?
    NSString* userID = self.userID;
    
    item.modified = [NSDate date];
    
    
    // update the modified of the list that contains the item
    ETA_ShoppingList* list = [self getShoppingList:item.shoppingListID];
    [self updateShoppingList:list completion:nil];
    
    
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
    
    if (completionHandler)
        completionHandler(item, nil);
    
    
    // update the item that follows this item
    ETA_ShoppingListItem* nextItem = [self localDBGetShoppingListItemWithPreviousItemID:item.uuid inList:item.shoppingListID userID:userID];
    if (nextItem)
    {
        nextItem.prevItemID = item.prevItemID;
        
        [self updateShoppingListItem:nextItem userID:userID completion:^(ETA_ShoppingListItem *updatedNextItem, NSError *error, BOOL fromServer) {
            if (!fromServer)
            {
                [self sendItemsUpdatedNotification:@[updatedNextItem]];
            }
        }];
    }
    
//    
//    [self sendNotificationForAdded:nil
//                           removed:@[item]
//                          modified:(nextItem) ? @[nextItem] : nil
//                              type:ETA_ShoppingListItem.class];
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
    [self updateShoppingList:list completion:nil];

    
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
- (ETA_ShoppingListItem*) getShoppingListItemWithOfferID:(NSString*)offerID inList:(NSString*)listID
{
    return [self localDBGetShoppingListItemWithOfferID:offerID inList:listID userID:self.userID];
}
- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter
{
    return [self getAllShoppingListItemsInList:listID withFilter:filter userID:self.userID];
}

- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter userID:(NSString*)userID
{
    NSArray* allItems = [self localDBGetAllShoppingListItemsForShoppingList:listID withFilter:ETA_ShoppingListItemFilter_All userID:userID];
    allItems = [self sortedShoppingListItemsByPrevItemID:allItems];
    
    if (filter == ETA_ShoppingListItemFilter_All)
    {
        return allItems;
    }
    else
    {
        return [allItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"tick == %d", (filter == ETA_ShoppingListItemFilter_Ticked) ? 1 : 0]];
    }
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
        case ETA_ShoppingListManager_PollRate_Fast:
            return kETA_ShoppingListManager_FastPollInterval;
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
                         
                         
                         if (!error)
                         {
                             ETA_ShoppingList* localList = [self localDBGetShoppingList:listID userID:userID];
                             [self saveLocallyAndNotifyChangesBetweenLocalShoppingLists: (localList) ? @[localList] : nil
                                                                     andListsFromServer: (serverList) ? @[serverList] : nil
                                                                                 userID: userID];
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
                                                   NSArray* localItems = [self getAllShoppingListItemsInList:listID withFilter:ETA_ShoppingListItemFilter_All userID:userID];
                                                   
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
    NSMutableArray* mergedObjects = [NSMutableArray new];
    
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
        
        [mergedObjects addObject:serverObj];
        
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
    
    if (mergedObjects.count)
        differencesDict[@"merged"] = mergedObjects;
    
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

- (BOOL) isShoppingListItem:(ETA_ShoppingListItem*)serverItem newerThanItem:(ETA_ShoppingListItem*)localItem
{
    // check the modified dates of the objects
    NSDate* localModifiedDate = localItem.modified;
    NSDate* serverModifiedDate = serverItem.modified;
    
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
        return YES;
    }
    // local version is newer - we shouldnt have polled while in the process of syncing, so do nothing
    else if (compare == NSOrderedDescending)
    {
        
    }
    // local and server are the same - do nothing
    else if (compare == NSOrderedSame)
    {
        
    }
    return NO;
}

- (void) saveLocallyAndNotifyChangesBetweenLocalShoppingListItems:(NSArray*)localItems andItemsFromServer:(NSArray*)serverItems userID:(NSString*)userID
{
    // make maps based on the objects uuids
    NSMutableDictionary* localItemsByUUID = [NSMutableDictionary dictionaryWithCapacity:localItems.count];
    for (ETA_ShoppingListItem* item in localItems)
        [localItemsByUUID setValue:item forKey:item.uuid];
    
    NSMutableDictionary* serverItemsByPrevItemID = [NSMutableDictionary dictionaryWithCapacity:serverItems.count];
    
    NSMutableArray* removed = [localItems mutableCopy];// objects that were removed from the server
    NSMutableArray* added = [NSMutableArray new]; // objects that were added to the server
    NSMutableArray* modified = [NSMutableArray new]; // objects that have changed on the server

    for (ETA_ShoppingListItem* serverItem in serverItems)
    {
        ETA_ShoppingListItem* localItem = [localItemsByUUID objectForKey:serverItem.uuid];
        
        // the object is on the server, but not locally. It needs to be added locally
        if (!localItem)
        {
            [added addObject:serverItem];
        }
        // the object exists both locally and on the server
        else
        {
            // mark as not needing to be removed
            [removed removeObject:localItem];
            
            // update the prevItemID
            if (!serverItem.prevItemID)
            {
                serverItem.prevItemID = localItem.prevItemID;
            }
            
            if ([self isShoppingListItem:serverItem newerThanItem:localItem])
            {
                [modified addObject:serverItem];
            }
        }
        
        if (serverItem.prevItemID)
            [serverItemsByPrevItemID setObject:serverItem forKey:serverItem.prevItemID];
    }
    
    // fill in the gaps made by removed items (relies on removed being in a sorted order - this is from the local items being passed in)
    [removed enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* removedLocalItem, NSUInteger idx, BOOL *stop) {
        ETA_ShoppingListItem* serverItemAfterLocalItem = serverItemsByPrevItemID[removedLocalItem.uuid];
        if (serverItemAfterLocalItem) {
            serverItemAfterLocalItem.prevItemID = removedLocalItem.prevItemID;
            [modified addObject:serverItemAfterLocalItem];
        }
    }];
//    [removed enumerateObjectsUsingBlock:^(ETA_ShoppingListItem* removedLocalItem, BOOL *stop) {
//        ETA_ShoppingListItem* serverItemAfterLocalItem = serverItemsByPrevItemID[removedLocalItem.uuid];
//        if (serverItemAfterLocalItem) {
//            serverItemAfterLocalItem.prevItemID = removedLocalItem.prevItemID;
//            [modified addObject:serverItemAfterLocalItem];
//        }
//    }];
//    
    
    // recreate the prevItemID and order index for all the new items
    NSArray* sortedServerItems = [self sortedShoppingListItemsByPrevItemID:serverItems];
    NSArray* changedItemsAfterResort = [self generatePrevItemIDForSortedItems:sortedServerItems];
    for (ETA_ShoppingListItem* changedServerItem in changedItemsAfterResort)
    {
        if ([modified containsObject:changedServerItem] == NO)
            [modified addObject:changedServerItem];
    }
    
//    
//
//    NSDictionary* differencesDict = [self getDifferencesBetweenLocalObjects:localItems
//                                                           andServerObjects:serverItems
//                                                               mergeHandler:^ETA_ModelObject *(ETA_ModelObject *serverObject, ETA_ModelObject *localObject) {
//                                                                   // if the server doesnt define a prevItemID then use the local item's prevItemID
//                                                                   // this allows for the server not implementing this feature yet
//                                                                   NSString* serverPrevID = ((ETA_ShoppingListItem*)serverObject).prevItemID;
//                                                                   NSString* localPrevID = ((ETA_ShoppingListItem*)localObject).prevItemID;
//                                                                   if (!serverPrevID)
//                                                                   {
//                                                                       ((ETA_ShoppingListItem*)serverObject).prevItemID = localPrevID;
//                                                                   }
//                                                                   // server has a different sort order - it needs to be marked as modified and the order index recalculated
//                                                                   else if ([serverPrevID isEqualToString:localPrevID] == NO)
//                                                                   {
//                                                                       ((ETA_ShoppingListItem*)serverObject).modified = [NSDate date];
//                                                                   }
//                                                                   return serverObject;
//                                                               }];
//
//    
//    NSArray* removed = differencesDict[@"removed"];
//    NSArray* added = differencesDict[@"added"];
//    NSArray* modified = differencesDict[@"modified"];
//    
////    NSArray* mergedObjects = differencesDict[@"merged"];
//    [self updateItemOrderingForItems:mergedObjects];
    
    
    NSUInteger changeCount = removed.count + added.count + modified.count;
    if (changeCount == 0)
        return;
    
    
    // recalc the orderID for all the items - those that have been modified will have their items changed
//    NSArray* allItems = [self localDBGetAllShoppingListItemsForShoppingList:nil withFilter:ETA_ShoppingListItemFilter_All userID:userID];
    
    
    
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
    
    [self sendItemsUpdatedNotification:modified];
    [self sendItemsRemovedNotification:removed];
    [self sendItemsAddedNotification:added];
    
//    [self sendNotificationForAdded:added removed:removed modified:modified type:ETA_ShoppingListItem.class];
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

- (NSOperation*) deleteFromServerOperationForObject:(ETA_DBSyncModelObject*)objToDelete remainingRetries:(NSUInteger)remainingRetries userID:(NSString*)userID
{
    return nil;
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
                                // we failed too many times - start a timer that will retry the deletes
                                if (remainingRetries <= 0)
                                {
                                    [self log:@"[DELETE %@] failed to delete '%@' for the last time - just delete locally", NSStringFromClass(objToDelete.class), ((ETA_ShoppingList*)objToDelete).name];
                                    // mark as needing to be deleted
                                    [self localDBUpdateSyncState:ETA_DBSyncState_Deleted forObject:objToDelete userID:userID];
                                }
                                // retry deleting the object from the server
                                else
                                {
                                    [self log: @"[DELETE %@] failed (%d remaining) to delete '%@'(%@) - %@ / %@", NSStringFromClass(objToDelete.class), remainingRetries, ((ETA_ShoppingList*)objToDelete).name, objToDelete.uuid, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                                    
                                    // mark as needing to be deleted
                                    [self localDBUpdateSyncState:ETA_DBSyncState_ToBeDeleted forObject:objToDelete userID:userID];
                                    
                                    [self deleteObjectFromServer:objToDelete remainingRetries:remainingRetries-1 userID:userID];
                                }
                            }
                        }];
}

- (NSOperation*) syncToServerOperationForObject:(ETA_DBSyncModelObject*)objToSync
                               remainingRetries:(NSUInteger)remainingRetries
                                         userID:(NSString*)userID
                                     completion:(void (^)(ETA_DBSyncModelObject* syncedObj, NSError* error))completionHandler
{
    @weakify(self);
    return [NSBlockOperation blockOperationWithBlock:^{
        
        @strongify(self);
        
        [self log: @"[SYNC %@] started '%@' (%@)", NSStringFromClass([objToSync class]), [(ETA_ShoppingList*)objToSync name], objToSync.uuid];
        
        // send request to insert/update to server
        [self serverInsertOrReplaceObject:objToSync forUser:userID completion:^(ETA_DBSyncModelObject* syncedObj, NSError *error) {
            
            // the user changed to a different user (not just logged off) while the request was being sent
            // we cannot use the response for anything now
            
            // TODO: specific error that the user has changed
            if (self.userID && [self.userID isEqualToString:userID]==NO)
                error = [NSError errorWithDomain:@"" code:0 userInfo:nil];
            
            
            // on success, mark as synced
            if (!error && syncedObj)
            {
                [self log: @"[SYNC %@] successfully synced '%@'(%@)", NSStringFromClass([syncedObj class]), [(ETA_ShoppingList*)syncedObj name], syncedObj.uuid];
                
                // mark locally as having been successfully synced (and save returned list back to localDB
                [self localDBUpdateSyncState:ETA_DBSyncState_Synced forObject:syncedObj userID:userID];
                
                // stop the retry timer if there are no more objects that need to be synced
                //                if ([self thereAreObjectsWithLocalChanges] == NO)
                //                    [self stopRetrySyncTimer];
                
                if (completionHandler)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(syncedObj, nil);
                    });
                }                
            }
            // a recoverable error happened while trying to send changes to the server
            else if ([error.domain isEqualToString:NSURLErrorDomain])
            {
                
                [self log: @"[SYNC %@] Retryable failure (%d remaining): sync '%@'(%@) - %@ / %@", NSStringFromClass([objToSync class]),remainingRetries, [(ETA_ShoppingList*)objToSync name], objToSync.uuid, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                
                // mark as un-synced
                [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:objToSync userID:userID];
                
                
                // add a copy of this operation to the top of the queue, so that it is retried
                NSOperation* retryOp = [self syncToServerOperationForObject:objToSync
                                                           remainingRetries:MAX(remainingRetries-1, 0)
                                                                     userID:userID
                                                                 completion:completionHandler];
                retryOp.queuePriority = NSOperationQueuePriorityVeryHigh;
                [[NSOperationQueue currentQueue] addOperation:retryOp];
                
                
                // if the insta-retry count is 0, sleep for a while before retrying
                if (remainingRetries <= 0)
                    sleep(self.retrySyncInterval);
            }
            // something bad happened, and we have no way of recovering - revert object and fail
            else
            {
                [self log: @"[SYNC %@] No-Retry sync failure: sync '%@'(%@) - %@ / %@", NSStringFromClass([objToSync class]), [(ETA_ShoppingList*)objToSync name], objToSync.uuid, error.userInfo[NSLocalizedDescriptionKey], error.userInfo[NSLocalizedFailureReasonErrorKey]];
                
                
                // Revert the object we tried to sync
                // Get the latest state from the server and save locally.
                // If it failed, delete the object
                [self serverGetObject:objToSync forUser:userID completion:^(ETA_DBSyncModelObject *serverObj, NSError *revertError) {
                    
                    // the user has changed since we made the server request - the server results are invalid
                    // in this case we dont shouldnt revert the local changes, we just return that there was a problem
                    // TODO: user changed error
                    if ([self.userID isEqualToString:userID])
                    {
                        if ([objToSync isKindOfClass:ETA_ShoppingList.class])
                        {
                            ETA_ShoppingList* localObj = [self localDBGetShoppingList:objToSync.uuid userID:userID];
                            
                            [self saveLocallyAndNotifyChangesBetweenLocalShoppingLists: (localObj) ? @[localObj] : nil
                                                                    andListsFromServer: (serverObj) ? @[serverObj] : nil
                                                                                userID: userID];
                        }
                        else if ([objToSync isKindOfClass:ETA_ShoppingListItem.class])
                        {
                            ETA_ShoppingListItem* localObj = [self localDBGetShoppingListItem:objToSync.uuid userID:userID];
                            [self saveLocallyAndNotifyChangesBetweenLocalShoppingListItems: (localObj) ? @[localObj] : nil
                                                                        andItemsFromServer: (serverObj) ? @[serverObj] : nil
                                                                                    userID: userID];
                        }
                    }
                    
                    // send completion handler back with the error
                    if (completionHandler)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completionHandler(nil, error);
                        });
                    }
                    
                }];
            }
        }];
        
    }];

}



- (void) syncObjectToServer:(ETA_DBSyncModelObject*)objToSync
           remainingRetries:(NSUInteger)remainingRetries
                     userID:(NSString*)userID
                 completion:(void (^)(ETA_DBSyncModelObject* syncedObj, NSError* error))completionHandler
{
    // cant sync if not connected
    if (!userID)
        return;
    
    [self localDBUpdateSyncState:ETA_DBSyncState_Syncing forObject:objToSync userID:userID];
    
    [self.serverQ addOperation:[self syncToServerOperationForObject:objToSync remainingRetries:remainingRetries userID:userID completion:completionHandler]];
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
        [self syncObjectToServer:objToSync remainingRetries:0 userID:userID completion:nil];
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
    return (lists) ?: @[];
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
        
        success = [ETA_ShoppingList insertOrReplaceList:list intoTable:tblName inDB:db error:nil];
    }];
    return success;
}

- (BOOL) localDBDeleteShoppingList:(NSString*)listID userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingList:userID];
        
        success = [ETA_ShoppingList deleteList:listID fromTable:tblName inDB:db error:nil];
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


#pragma mark Reordering

- (void) reorderItems:(NSArray*)items
{
    NSLog(@"Reordering:");
//    for (ETA_ShoppingListItem* item in items)
//    {
//        NSLog(@" %@ '%@' (%d) id:'%@' prevID:'%@'", (item.tick)?@"x":@"-", item.name, item.orderIndex, item.uuid, item.prevItemID);
//    }
//    NSLog(@"ReorderedItems with new orderID:");
    
    
    
    NSString* userID = self.userID;
    
    NSMutableArray* modifiedItems = [NSMutableArray new];
    
    NSString* prevItemID = kETA_ShoppingListManager_FirstPrevItemID;
    NSDate* modifiedDate = [NSDate date];
    for (ETA_ShoppingListItem* sortedItem in items)
    {
        ETA_ShoppingListItem* existingItem = [self localDBGetShoppingListItem:sortedItem.uuid userID:userID];
        
        // skip items that dont exist
        if (!existingItem)
            continue;
        
        NSLog(@" %@ '%@' id:'%@' prevID:'%@'->'%@'", (existingItem.tick)?@"x":@"-", existingItem.name, existingItem.uuid, existingItem.prevItemID, prevItemID);
        
        if ([prevItemID isEqualToString:existingItem.prevItemID] == NO)
        {
            existingItem.modified = modifiedDate;
            existingItem.prevItemID = prevItemID;
        
        
            // we are logged in - try to sending to the server
            if (userID)
            {
                [self syncObjectToServer:existingItem remainingRetries:kETA_ShoppingListManager_DefaultRetryCount userID:userID completion:nil];
            }
            // no user - simply send the item to the local db
            else
            {
                [self localDBUpdateSyncState:ETA_DBSyncState_ToBeSynced forObject:existingItem userID:userID];
            }
            [modifiedItems addObject:existingItem];
        }
        prevItemID = existingItem.uuid;
    }
    
    if (modifiedItems.count)
        [self sendNotificationForAdded:nil removed:nil modified:modifiedItems type:ETA_ShoppingListItem.class];
}

//- (void) reorderItem:(ETA_ShoppingListItem*)itemToMove fromBeforeItem:(ETA_ShoppingListItem*)fromBeforeItem toBeforeItem:(ETA_ShoppingListItem*)toBeforeItem toAfterItem:(ETA_ShoppingListItem*)toAfterItem
//{
//    NSString* userID = self.userID;
//    
//    // update the relevant item prevID values
//    fromBeforeItem.prevItemID = itemToMove.prevItemID;
//    toBeforeItem.prevItemID = itemToMove.uuid;
//    
//    // moving to the end of the list.
//    if (!toBeforeItem)
//    {
//        itemToMove.prevItemID = toAfterItem.uuid;
//    }
//    else
//    {
//        itemToMove.prevItemID = toBeforeItem.prevItemID;
//    }
//    
//    
//    
//    
//    NSArray* allItems = [self localDBGetAllShoppingListItemsForShoppingList:itemToMove.shoppingListID withFilter:ETA_ShoppingListItemFilter_All userID:userID];
//    
//    
//    [self updateItemOrderingForItems:allItems];
//    
//    
//    
//}
//
//- (void) localDBUpdateSortOrderIndexesForItems:(NSArray*)items userID:(NSString*)userID
//{
//    if (!items)
//        return;
//    
//    NSArray* changedItems = [self changeSortOrderIndexesForItems:items];
//    
//    if (changedItems.count)
//        NSLog(@"sort order changed for: %@", changedItems);
//    
//    for (ETA_ShoppingListItem* item in changedItems)
//        [self localDBInsertOrReplaceShoppingListItem:item userID:userID];
//}



- (NSArray*) generatePrevItemIDForSortedItems:(NSArray*)sortedItems
{
    NSMutableArray* changedItems = [NSMutableArray new];
    
    NSString* prevItemID = kETA_ShoppingListManager_FirstPrevItemID;
    NSDate* modifiedDate = [NSDate date];
    for (ETA_ShoppingListItem* item in sortedItems)
    {
        if (![item.prevItemID isEqualToString:prevItemID])
        {
            item.prevItemID = prevItemID;
            item.modified = modifiedDate;
            [changedItems addObject:item];
        }
        
        prevItemID = item.uuid;
    }
    
    return changedItems;
}

- (NSArray*) updatePrevItemIDForItems:(NSArray*)items
{
    // sort by existing prev item ids, if they exist
    NSArray* sortedItems = [self sortedShoppingListItemsByPrevItemID:items];
    
    return [self generatePrevItemIDForSortedItems:sortedItems];
}

- (NSArray*) sortedShoppingListItemsByPrevItemID:(NSArray*)items
{
    NSMutableDictionary* itemsByPrevItemID = [NSMutableDictionary dictionary];
    
    NSMutableArray* firstItems = [NSMutableArray array];
    
    NSMutableArray* orderedItems = [NSMutableArray new];
    
    for (ETA_ShoppingListItem* item in items)
    {
        NSString* prevID = item.prevItemID;
        if (prevID)
        {
            if ([prevID isEqualToString:kETA_ShoppingListManager_FirstPrevItemID])
                [firstItems addObject:item];
            else
                itemsByPrevItemID[prevID] = item;
        }
        // it doesnt have a previous item - it isnt in the sorting
        else
        {
            [orderedItems addObject:item];
        }
    }
    NSUInteger unorderedItemCount = orderedItems.count;
    
    // go through all the items that have a prev-item-id
    for (ETA_ShoppingListItem* firstItem in firstItems)
    {
        ETA_ShoppingListItem* nextItem = firstItem;
        
        while (nextItem)
        {
            [orderedItems addObject:nextItem];
            
            // clear from item dict
            [itemsByPrevItemID removeObjectForKey:nextItem.prevItemID];
            
            // move on to the next item
            nextItem = itemsByPrevItemID[nextItem.uuid];
        }
    }
    
    // mark the remaining unsorted items
    for (ETA_ShoppingListItem* item in itemsByPrevItemID.allValues)
    {
        [orderedItems insertObject:item atIndex:unorderedItemCount];
        unorderedItemCount++;
    }
    
    return orderedItems;
}


//
//- (NSArray*) changeSortOrderIndexesForItems:(NSArray*)items
//{
//    NSMutableDictionary* itemsByPrevItemID = [NSMutableDictionary dictionary];
//    
//    NSMutableArray* changedItems = [NSMutableArray array];
//    NSMutableArray* firstItems = [NSMutableArray array];
//    
//    for (ETA_ShoppingListItem* item in items)
//    {
//        NSString* prevID = item.prevItemID;
//        if (prevID)
//        {
//            if (prevID.length == 0)
//                [firstItems addObject:item];
//            else
//                itemsByPrevItemID[prevID] = item;
//        }
//        // it doesnt have a previous item - it isnt in the sorting
//        else if (item.orderIndex != -1)
//        {
//            item.orderIndex = -1;
//            [changedItems addObject:item];
//        }
//    }
//    
//    for (ETA_ShoppingListItem* firstItem in firstItems)
//    {
//        NSUInteger orderIndex = 0;
//        ETA_ShoppingListItem* nextItem = firstItem;
//        
//        while (nextItem)
//        {
//            if (nextItem.orderIndex != orderIndex)
//            {
//                nextItem.orderIndex = orderIndex;
//                [changedItems addObject:nextItem];
//            }
//            
//            orderIndex++;
//            
//            // clear from item dict
//            [itemsByPrevItemID setValue:nil forKey:nextItem.prevItemID];
//            
//            // move on to the next item
//            nextItem = itemsByPrevItemID[nextItem.uuid];
//        }
//    }
//    
//    // mark the remaining unsorted items
//    for (ETA_ShoppingListItem* item in itemsByPrevItemID.allValues)
//    {
//        if (item.orderIndex != -1)
//        {
//            item.orderIndex = -1;
//            [changedItems addObject:item];
//        }
//    }
//    
//    return changedItems;
//}



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

- (ETA_ShoppingListItem*) localDBGetShoppingListItemWithOfferID:(NSString*)offerID inList:(NSString*)listID userID:(NSString*)userID
{
    __block ETA_ShoppingListItem* item = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        item = [ETA_ShoppingListItem getItemWithOfferID:offerID inList:listID fromTable:tblName inDB:db];
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
        
        success = [ETA_ShoppingListItem insertOrReplaceItem:item intoTable:tblName inDB:db error:nil];
    }];
    return success;
}

- (BOOL) localDBDeleteShoppingListItem:(NSString*)itemID userID:(NSString*)userID
{
    __block BOOL success = NO;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        success = [ETA_ShoppingListItem deleteItem:itemID fromTable:tblName inDB:db error:nil];
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

- (ETA_ShoppingListItem*) localDBGetShoppingListItemWithPreviousItemID:(NSString*)prevItemID inList:(NSString*)listID userID:(NSString*)userID
{
    __block ETA_ShoppingListItem* item = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSString* tblName = [[self class] localDBTableName_ShoppingListItem:userID];
        
        item = [ETA_ShoppingListItem getItemWithPrevItemID:prevItemID inList:listID fromTable:tblName inDB:db];
    }];
    return item;
}




#pragma mark - Server methods


- (void) serverGetObject:(ETA_DBSyncModelObject *)obj forUser:(NSString*)userID completion:(void (^)(ETA_DBSyncModelObject* responseObj, NSError* error))completionHandler
{
    if ([obj isKindOfClass:ETA_ShoppingList.class])
    {
        [self serverGetShoppingList:obj.uuid forUser:userID completion:completionHandler];
    }
    else if ([obj isKindOfClass:ETA_ShoppingListItem.class])
    {
        [self serverGetShoppingListItem:obj.uuid inShoppingList:((ETA_ShoppingListItem*)obj).shoppingListID forUser:userID completion:completionHandler];
    }
    else if (completionHandler)
    {
        //TODO: Error if invalid obj type
        completionHandler(nil, nil);
    }
}

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

- (void) serverGetShoppingListItem:(NSString*)itemID inShoppingList:(NSString*)listID forUser:(NSString*)userID completion:(void (^)(ETA_ShoppingListItem* item, NSError* error))completionHandler
{
    if (!completionHandler)
        return;
    
    //TODO: error when userID is invalid
    if (!userID || !listID)
    {
        completionHandler(nil, nil);
        return;
    }
    
    //   "/v2/users/{userID}/shoppinglists/{listID}/items/{itemID}"
    NSString* request = [ETA_API pathWithComponents:@[ ETA_API.users,
                         userID,
                         ETA_API.shoppingLists,
                         listID,
                         ETA_API.shoppingListItems,
                         itemID]];
    
    [self.eta api:request
             type:ETARequestTypeGET
       parameters:nil
         useCache:NO
       completion:^(id response, NSError *error, BOOL fromCache) {
           ETA_ShoppingListItem* item = [ETA_ShoppingListItem objectFromJSONDictionary:response];
           
           completionHandler(item, error);
       }];
    
}


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
               
               if (syncedItem.prevItemID == nil)
               {
                   syncedItem.prevItemID = item.prevItemID;
               }
               
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
    
    NSMutableDictionary* jsonDict = [[item JSONDictionary] mutableCopy];
    
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
       parameters:jsonDict
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
