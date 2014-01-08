//
//  ETA_ListManager.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ListManager.h"

#import "ETA.h"
#import "ETA_ListSyncr.h"

#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

#import "ETA_ShoppingListItem.h"
#import "ETA_ShoppingListItem+FMDB.h"
#import "ETA_ShoppingList.h"
#import "ETA_ShoppingList+FMDB.h"
#import "ETA_ListShare.h"
#import "ETA_ListShare+FMDB.h"

#import "ETA_User.h"

NSString* const ETA_ListManager_ChangeNotification_Lists = @"ETA_ListManager_ChangeNotification_ServerLists";
NSString* const ETA_ListManager_ChangeNotification_ListItems = @"ETA_ListManager_ChangeNotification_ServerListItems";

NSString* const ETA_ListManager_ChangeNotificationInfo_FromServerKey = @"fromServer";
NSString* const ETA_ListManager_ChangeNotificationInfo_ModifiedKey = @"modified";
NSString* const ETA_ListManager_ChangeNotificationInfo_AddedKey = @"added";
NSString* const ETA_ListManager_ChangeNotificationInfo_RemovedKey = @"removed";


NSString* const kETA_ListManager_ErrorDomain = @"ETA_ListManager_ErrorDomain";
NSString* const kETA_ListManager_FirstPrevItemID = @"00000000-0000-0000-0000-000000000000";
NSString* const kETA_ListManager_DefaultUserAccessAcceptURL = @"http://www.etilbudsavis.dk/";
NSInteger const kETA_ListManager_LatestDBVersion = 4;

@interface ETA_ListManager ()<ETA_ListSyncrDBHandlerProtocol>

@property (nonatomic, strong) ETA* eta;

@property (nonatomic, strong) ETA_ListSyncr* syncr;
@property (nonatomic, readwrite, assign) BOOL hasSynced;

@property (nonatomic, strong) FMDatabaseQueue *dbQ;

@end


@implementation ETA_ListManager

+ (instancetype) sharedManager
{
    if (!ETA.SDK)
        return nil;
    
    static ETA_ListManager* sharedListManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedListManager = [self managerWithETA:ETA.SDK localDBFilePath:nil];
    });
    return sharedListManager;
}
+ (instancetype) managerWithETA:(ETA*)eta localDBFilePath:(NSString*)localDBFilePath
{
    ETA_ListManager* manager = [[ETA_ListManager alloc] initWithETA:eta localDBFilePath:localDBFilePath];
    return manager;
}

+ (NSString*)defaultLocalDBFilePath
{
    // setup the local DB
    NSURL* appDocsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSString* localDBPath = [[appDocsURL URLByAppendingPathComponent:@"local_lists.db"] path];
 
    return localDBPath;
}

- (id)init
{
    return [self initWithETA:nil localDBFilePath:nil];
}

- (id)initWithETA:(ETA*)eta localDBFilePath:(NSString*)dbFilePath
{
    if ((self = [super init]))
    {
        self.eta = eta;
        
        self.hasSynced = NO;
        
        if (eta)
            self.syncr = [ETA_ListSyncr syncrWithETA:eta localDBQueryHandler:self];
        
        if (!dbFilePath)
            dbFilePath = [[self class] defaultLocalDBFilePath];
        NSLog (@"[ETA_ListManager] LocalDB: '%@'", dbFilePath);
        
        [self localDBCreateTablesAt:dbFilePath];
        
        self.verbose = NO;
    }
    return self;
}

- (void) dealloc
{
    self.syncr = nil;
    self.dbQ = nil;
}

- (BOOL) dropAllDataForUserID:(id)userID error:(NSError * __autoreleasing *)error
{
    NSMutableArray* allObjs = [NSMutableArray array];
    [allObjs addObjectsFromArray:[self getAllDBObjectsWithSyncStates:nil forUser:userID objClass:ETA_ShoppingListItem.class]];
    [allObjs addObjectsFromArray:[self getAllDBObjectsWithSyncStates:nil forUser:userID objClass:ETA_ShoppingList.class]];
    [allObjs addObjectsFromArray:[self getAllDBObjectsWithSyncStates:nil forUser:userID objClass:ETA_ListShare.class]];
    
    return [self deleteDBObjects:allObjs error:error];
}
- (void) forceSyncToServer:(void(^)())completionHandler
{
    if (!self.syncr) {
        if (completionHandler)
            completionHandler();
        return;
    }
    
    [self.syncr performSync:YES completionHandler:^(BOOL success) {
        if (completionHandler)
            completionHandler();
    }];
}
- (void) sendNotificationOfLocalModified:(NSArray*)modified added:(NSArray*)added removed:(NSArray*)removed objClass:(Class)objClass
{
    NSMutableDictionary* diffs = [NSMutableDictionary dictionaryWithCapacity:3];
    [diffs setValue:modified forKey:ETA_ListManager_ChangeNotificationInfo_ModifiedKey];
    [diffs setValue:added forKey:ETA_ListManager_ChangeNotificationInfo_AddedKey];
    [diffs setValue:removed forKey:ETA_ListManager_ChangeNotificationInfo_RemovedKey];
    
    [self sendNotificationOfDifferences:diffs fromServer:NO objClass:objClass];
}

- (void) sendNotificationOfDifferences:(NSDictionary*)diffs fromServer:(BOOL)fromServer objClass:(Class)objClass
{
    NSUInteger removedCount = [diffs[ETA_ListManager_ChangeNotificationInfo_RemovedKey] count];
    NSUInteger addedCount = [diffs[ETA_ListManager_ChangeNotificationInfo_AddedKey] count];
    NSUInteger modifiedCount = [diffs[ETA_ListManager_ChangeNotificationInfo_ModifiedKey] count];
    
    
    if (addedCount + removedCount + modifiedCount == 0)
        return;
    
    
    NSString* notificationName = nil;
    if ( objClass == ETA_ShoppingList.class )
    {
        notificationName = ETA_ListManager_ChangeNotification_Lists;
        
        [self log:@"[List Notification] %d added / %d removed / %d modified", addedCount, removedCount, modifiedCount];
    }
    else if ( objClass == ETA_ShoppingListItem.class )
    {
        notificationName = ETA_ListManager_ChangeNotification_ListItems;
        
        [self log:@"[Item Notification] %d added / %d removed / %d modified", addedCount, removedCount, modifiedCount];
    }
    
    if (!notificationName)
        return;
    
    NSMutableDictionary* mutableDiffs = [diffs mutableCopy];
    mutableDiffs[ETA_ListManager_ChangeNotificationInfo_FromServerKey] = @(fromServer);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:mutableDiffs];
}



#pragma mark - Syncr

- (void) setSyncr:(ETA_ListSyncr *)syncr
{
    if (_syncr == syncr)
        return;

    if (_syncr)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:ETA_ListSyncr_ChangeNotification_Lists
                                                      object:_syncr];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:ETA_ListSyncr_ChangeNotification_ListItems
                                                      object:_syncr];
        [_syncr removeObserver:self forKeyPath:@"pullSyncCount"];
    }
    _syncr = syncr;
    
    if (_syncr)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(syncr_listsChangedNotification:)
                                                     name:ETA_ListSyncr_ChangeNotification_Lists
                                                   object:_syncr];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(syncr_listItemsChangedNotification:)
                                                     name:ETA_ListSyncr_ChangeNotification_ListItems
                                                   object:_syncr];
        
        [_syncr addObserver:self forKeyPath:@"pullSyncCount" options:0 context:NULL];
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"pullSyncCount"])
    {
        BOOL hasSynced = (self.syncr.pullSyncCount > 0);
        if (hasSynced != self.hasSynced)
            self.hasSynced = hasSynced;
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void) syncr_listsChangedNotification:(NSNotification*)notification
{
    NSDictionary* syncrChanges = notification.userInfo;
    
    NSArray* added = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_AddedKey];
    NSArray* modified = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey];
    NSArray* removed = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey];
    
    NSDictionary* mappedChanges = [NSMutableDictionary dictionary];
    [mappedChanges setValue:added forKey:ETA_ListManager_ChangeNotificationInfo_AddedKey];
    [mappedChanges setValue:removed forKey:ETA_ListManager_ChangeNotificationInfo_RemovedKey];
    [mappedChanges setValue:modified forKey:ETA_ListManager_ChangeNotificationInfo_ModifiedKey];
    
    
    [self sendNotificationOfDifferences:mappedChanges fromServer:YES objClass:ETA_ShoppingList.class];
}
- (void) syncr_listItemsChangedNotification:(NSNotification*)notification
{
    NSDictionary* syncrChanges = notification.userInfo;
    
    NSArray* added = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_AddedKey];
    NSMutableArray* modified = [syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey] mutableCopy];
    NSArray* removed = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey];
    
    
    NSArray* itemsToCheck = [added?:@[] arrayByAddingObjectsFromArray:modified];
    NSMutableDictionary* itemsWithoutPrevIDByListID = [NSMutableDictionary dictionary];
    NSMutableArray* itemsToUpdate = [NSMutableArray new];
//    NSMutableArray* listsToUpdate = [NSMutableArray new];
    for (ETA_ShoppingListItem* item in itemsToCheck)
    {
        if (item.prevItemID == nil)
        {
//            ETA_ShoppingListItem* existingItem = [self getListItem:item.uuid];
//            if (existingItem)
//            {
//                item.prevItemID = existingItem.prevItemID;
//                item.modified = [NSDate date];
//                [listIDsToUpdate addObject:item.shoppingListID];
            //                [itemsToUpdate addObject:item];
            //            }
            //            else
            //            {
            NSMutableArray* items = itemsWithoutPrevIDByListID[item.shoppingListID];
            if (!items) {
                items = [NSMutableArray array];
                itemsWithoutPrevIDByListID[item.shoppingListID] = items;
            }
            ETA_ShoppingListItem* prevItem = [items lastObject];
            item.prevItemID = prevItem.uuid ?: kETA_ListManager_FirstPrevItemID;
            item.modified = [NSDate date];
            item.state = ETA_DBSyncState_ToBeSynced;
            [items addObject:item];
            [itemsToUpdate addObject:item];
            //            }
        }
    }
    
    
    // update the next item
    [itemsWithoutPrevIDByListID enumerateKeysAndObjectsUsingBlock:^(NSString* listID, NSArray* itemsWithoutPrevID, BOOL *stop) {
        ETA_ShoppingListItem* prevItem = (ETA_ShoppingListItem*)[itemsWithoutPrevID lastObject];
        ETA_ShoppingListItem* nextItem = [self getListItemWithPreviousItemID:kETA_ListManager_FirstPrevItemID inList:listID];
        if (nextItem && [nextItem.uuid isEqualToString:prevItem.uuid] == NO)
        {
            nextItem.prevItemID = prevItem.uuid;
            nextItem.modified = [NSDate date];
            nextItem.state = ETA_DBSyncState_ToBeSynced;
            [itemsToUpdate addObject:nextItem];
            [modified addObject:nextItem];
        }
        
//        ETA_ShoppingList* list = [self getList:listID];
//        list.modified = [NSDate date];
//        list.state = ETA_DBSyncState_ToBeSynced;
//        [listsToUpdate addObject:list];
//        [self updateList:list error:nil];
    }];
    if (itemsToUpdate.count)
    {
        NSError* err = nil;
        if (![self updateDBObjects:itemsToUpdate error:&err])
        {
            NSLog(@"unable to update items without prevID");
        }
    }
//    if (listsToUpdate.count)
//    {
//        NSError* err = nil;
//        if (![self updateDBObjects:listsToUpdate error:&err])
//        {
//            NSLog(@"unable to update lists for items without prevID");
//        }
//    }
    
    
    NSDictionary* mappedChanges = [NSMutableDictionary dictionary];
    [mappedChanges setValue:added forKey:ETA_ListManager_ChangeNotificationInfo_AddedKey];
    [mappedChanges setValue:removed forKey:ETA_ListManager_ChangeNotificationInfo_RemovedKey];
    [mappedChanges setValue:modified forKey:ETA_ListManager_ChangeNotificationInfo_ModifiedKey];
    
    
    [self sendNotificationOfDifferences:mappedChanges fromServer:YES objClass:ETA_ShoppingListItem.class];
}



- (void) setSyncRate:(ETA_ListManager_SyncRate)syncRate
{
    self.syncr.pollRate = syncRate;
}
- (ETA_ListManager_SyncRate) syncRate
{
    return self.syncr ? (ETA_ListManager_SyncRate)self.syncr.pollRate : ETA_ListManager_SyncRate_None;
}




#pragma mark - Public methods

#pragma mark Lists
- (ETA_ShoppingList*) createShoppingList:(NSString*)name
                                 forUser:(ETA_User*)user
                                   error:(NSError * __autoreleasing *)error
{
    NSString* uuid = [[self class] generateUUID];
    
    ETA_ShoppingList* list = [ETA_ShoppingList shoppingListWithUUID:uuid
                                                               name:name
                                                       modifiedDate:nil
                                                             access:ETA_ShoppingList_Access_Private];
    if (user)
    {
        list.syncUserID = user.uuid;
        
        ETA_ListShare* share = [[ETA_ListShare alloc] init];
        share.listUUID = list.uuid;
        share.userEmail = user.email;
        share.userName = user.name;
        share.syncUserID = user.uuid;
        share.access = ETA_ListShare_Access_Owner;
        share.accepted = YES;
        
        if (![self updateDBObjects:@[share] error:error])
            return NO;
        
        list.shares = @[share];
    }
    
    BOOL success = [self addList:list error:error];
    
    return (success) ? list : nil;
}

- (ETA_ShoppingList*) createWishList:(NSString*)name
                             forUser:(ETA_User*)user
                               error:(NSError * __autoreleasing *)error
{
    
    NSString* uuid = [[self class] generateUUID];
    
    ETA_ShoppingList* list = [ETA_ShoppingList wishListWithUUID:uuid
                                                           name:name
                                                   modifiedDate:nil
                                                         access:ETA_ShoppingList_Access_Private];
    
    if (user)
    {
        list.syncUserID = user.uuid;
        
        ETA_ListShare* share = [[ETA_ListShare alloc] init];
        share.listUUID = list.uuid;
        share.userEmail = user.email;
        share.userName = user.name;
        share.syncUserID = user.uuid;
        share.access = ETA_ListShare_Access_Owner;
        share.accepted = YES;
        
        if (![self updateDBObjects:@[share] error:error])
            return NO;
        
        list.shares = @[share];
    }
    
    BOOL success = [self addList:list error:error];
    
    return (success) ? list : nil;
}


- (BOOL) addList:(ETA_ShoppingList*)list error:(NSError * __autoreleasing *)error
{
    list.modified = [NSDate date];
    list.state = ETA_DBSyncState_ToBeSynced;
    
    NSArray* added = @[list];
    BOOL success = [self updateDBObjects:added error:error];
    
    if (success)
        [self sendNotificationOfLocalModified:nil added:added removed:nil objClass:ETA_ShoppingList.class];
    
    return success;
}

- (BOOL) updateList:(ETA_ShoppingList*)list error:(NSError * __autoreleasing *)error
{
    list.modified = [NSDate date];
    list.state = ETA_DBSyncState_ToBeSynced;
    
    NSArray* modified = @[list];
    BOOL success = [self updateDBObjects:modified error:error];
    
    if (success)
        [self sendNotificationOfLocalModified:modified added:nil removed:nil objClass:ETA_ShoppingList.class];
    
    return success;
}


- (BOOL) removeList:(ETA_ShoppingList*)list error:(NSError * __autoreleasing *)error
{
    NSDate* modified = [NSDate date];
    NSMutableArray* objsToUpdate = [NSMutableArray array];
    
    list.modified = modified;
    list.state = ETA_DBSyncState_ToBeDeleted;
    [objsToUpdate addObject:list];
    
    // mark all the items as deleted
    NSArray* allItems = [self getAllListItemsInList:list.uuid sortedByPreviousItemID:NO];
    for (ETA_ShoppingListItem* item in allItems)
    {
        item.modified = modified;
        item.state = ETA_DBSyncState_ToBeDeleted;
        [objsToUpdate addObject:item];
    }
    
    // if there is no sync-user for the objects, just delete them straight away. otherwise, mark as deleted
    BOOL success = NO;
    if (!list.syncUserID)
        success = [self deleteDBObjects:objsToUpdate error:error];
    else
        success = [self updateDBObjects:objsToUpdate error:error];
    
    if (success)
    {
        [self sendNotificationOfLocalModified:nil added:nil removed:@[list] objClass:ETA_ShoppingList.class];
        [self sendNotificationOfLocalModified:nil added:nil removed:allItems objClass:ETA_ShoppingListItem.class];
    }
    
    return success;
}


- (ETA_ShoppingList*) getList:(NSString*)listID
{
    return (ETA_ShoppingList*)[self getDBObjectWithUUID:listID objClass:ETA_ShoppingList.class];
}

- (NSArray*) getAllListsForUser:(NSString*)userID
{
    return [self getAllDBObjectsWithSyncStates:[self activeSyncStates]
                                       forUser:userID ?: NSNull.null
                                      objClass:ETA_ShoppingList.class];
}

- (BOOL) moveListsFromUser:(ETA_User*)fromUser toUser:(ETA_User*)toUser error:(NSError * __autoreleasing *)error
{
    NSArray* listsToMigrate = [self getAllListsForUser:fromUser.uuid];
    BOOL shouldDrop = YES;
    for (ETA_ShoppingList* listToMigrate in listsToMigrate)
    {
        NSArray* itemsToMigrate = [self getAllListItemsInList:listToMigrate.uuid sortedByPreviousItemID:YES];
        if (itemsToMigrate.count)
        {
            ETA_ShoppingList* list = [listToMigrate copy];
            list.uuid = [[self class] generateUUID];
            list.syncUserID = toUser.uuid;
            
            if (toUser)
            {
                ETA_ListShare* share = [[ETA_ListShare alloc] init];
                share.listUUID = list.uuid;
                share.userEmail = toUser.email;
                share.userName = toUser.name;
                share.syncUserID = toUser.uuid;
                share.access = ETA_ListShare_Access_Owner;
                share.accepted = YES;
                
                if (![self updateDBObjects:@[share] error:error])
                {
                    shouldDrop = NO;
                    continue;
                }
                
                list.shares = @[share];
            }
            else
            {
                list.shares = nil;
            }
            
            if (![self addList:list error:error])
            {
                shouldDrop = NO;
                continue;
            }
            
            NSString* prevItemID = kETA_ListManager_FirstPrevItemID;
            for (ETA_ShoppingList* itemToMigrate in itemsToMigrate)
            {
                ETA_ShoppingListItem* item = [itemToMigrate copy];
                item.uuid = [[self class] generateUUID];
                item.prevItemID = prevItemID;
                item.syncUserID = toUser.uuid;
                item.shoppingListID = list.uuid;
                item.creator = toUser.email;
                
                prevItemID = item.uuid;
                
                if (![self addListItem:item error:error])
                {
                    shouldDrop = NO;
                    continue;
                }
            }
        }
    }
//    if (shouldDrop)
//        [self dropAllDataForUserID:(!fromUser) ? NSNull.null : fromUser error:error];
    
    return YES;
}
#pragma mark - Shares

- (ETA_ListShare*) getShareForUserEmail:(NSString*)userEmail inList:(NSString*)listID
{
    __block ETA_ListShare* share = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        share = [ETA_ListShare getShareForUserEmail:userEmail inList:listID fromTable:[self localSharesTableName] inDB:db];
    }];
    return share;
}

- (BOOL) removeShareForUserEmail:(NSString*)userEmail inList:(NSString*)listID asUser:(NSString*)syncUserID error:(NSError * __autoreleasing *)error
{
    
    if (!listID || !userEmail)
    {
        *error = [NSError errorWithDomain:kETA_ListManager_ErrorDomain
                                     code:ETA_ListManager_ErrorCode_MissingParameter
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Can't remove access - invalid listID or userEmail",@"")}];
        return NO;
    }
    
    
    ETA_ListShare* share = [self getShareForUserEmail:userEmail inList:listID];
    
    BOOL success = YES;
    if (share)
    {
        share.state = ETA_DBSyncState_ToBeDeleted;
        share.syncUserID = syncUserID;
        
        if (!syncUserID)
        {
            success = [self deleteDBObjects:@[share] error:error];
        }
        else
        {
            success = [self updateDBObjects:@[share] error:error];
        }
    }
    
    return success;
}

- (BOOL) setShareAccess:(ETA_ListShare_Access)shareAccess
           forUserEmail:(NSString*)userEmail
                 inList:(NSString*)listID
              acceptURL:(NSString*)acceptURL
                 asUser:(NSString*)syncUserID
                  error:(NSError * __autoreleasing *)error
{
    if (shareAccess == ETA_ListShare_Access_None)
    {
        return [self removeShareForUserEmail:userEmail inList:listID asUser:syncUserID error:error];
    }

    if (!listID || !userEmail)
    {
        *error = [NSError errorWithDomain:kETA_ListManager_ErrorDomain
                                     code:ETA_ListManager_ErrorCode_MissingParameter
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Can't remove access - invalid listID or userEmail",@"")}];
        return NO;
    }
    
    ETA_ListShare* share = [self getShareForUserEmail:userEmail inList:listID];
    if (!share)
    {
        share = [ETA_ListShare new];
        share.userEmail = userEmail;
        share.userName = userEmail;
        share.accepted = NO;
        share.listUUID = listID;
    }
    
    share.access = shareAccess;
    share.acceptURL = acceptURL;
    share.state = ETA_DBSyncState_ToBeSynced;
    share.syncUserID = syncUserID;
    
    BOOL success = [self updateDBObjects:@[share] error:error];
    
    return success;
}

#pragma mark List Items

- (ETA_ShoppingListItem*) createListItem:(NSString *)name
                                 offerID:(NSString*)offerID
                            creatorEmail:(NSString*)creatorEmail
                                  inList:(NSString*)listID
                                   error:(NSError * __autoreleasing *)error
{
    if (!listID.length || !name.length)
    {
        *error = [NSError errorWithDomain:kETA_ListManager_ErrorDomain
                                     code:ETA_ListManager_ErrorCode_MissingParameter
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Can't create ListItem - invalid name or listID",@"")}];
        return NO;
    }
    
    
    ETA_ShoppingListItem* item = [ETA_ShoppingListItem new];
    item.uuid = [[self class] generateUUID];
    item.name = name;
    item.shoppingListID = listID;
    item.count = 1;
    item.offerID = offerID;
    item.creator = creatorEmail;
    item.prevItemID = kETA_ListManager_FirstPrevItemID;
    
    // take the sync-user from the list it is in
    ETA_ShoppingList* list = [self getList:listID];
    item.syncUserID = list.syncUserID;
    
    BOOL success = [self addListItem:item error:error];
    return (success) ? item : nil;
}

- (BOOL) addListItem:(ETA_ShoppingListItem *)item error:(NSError * __autoreleasing *)error
{
    return [self updateListItem:item error:error];
}

- (BOOL) updateListItem:(ETA_ShoppingListItem *)item error:(NSError * __autoreleasing *)error
{
    if (!item.uuid.length || !item.shoppingListID.length)
    {
        *error = [NSError errorWithDomain:kETA_ListManager_ErrorDomain
                                     code:ETA_ListManager_ErrorCode_MissingParameter
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Can't update ListItem - invalid uuid or listID",@"")}];
        return NO;
    }
    
    NSDate* modified = [NSDate date];
    NSString* listID = item.shoppingListID;
    
    ETA_ShoppingListItem* existingItem = [self getListItem:item.uuid];
    
    NSMutableArray* modifiedItems = [NSMutableArray new];
    NSMutableArray* addedItems = [NSMutableArray new];
    
    // update the item
    item.modified = modified;
    item.state = ETA_DBSyncState_ToBeSynced;
    if (existingItem)
        [modifiedItems addObject:item];
    else
        [addedItems addObject:item];
    
    
    // we are adding the item - the next item is the item that is after the new item's prevItemID
    // point this item at the new item
    if (!existingItem)
    {
        ETA_ShoppingListItem* nextItem = [self getListItemWithPreviousItemID:item.prevItemID inList:listID];
        if (nextItem)
        {
            nextItem.prevItemID = item.uuid;
            nextItem.modified = modified;
            nextItem.state = ETA_DBSyncState_ToBeSynced;
            [modifiedItems addObject:nextItem];
        }
    }
    // we are moving the item. change both the old & new NextItem's prevItemID
    else if ([existingItem.prevItemID isEqualToString:item.prevItemID] == NO)
    {
        ETA_ShoppingListItem* oldNextItem = [self getListItemWithPreviousItemID:item.uuid inList:listID];
        if (oldNextItem && [oldNextItem.prevItemID isEqualToString:existingItem.prevItemID] == NO)
        {
            oldNextItem.prevItemID = existingItem.prevItemID;
            oldNextItem.modified = modified;
            oldNextItem.state = ETA_DBSyncState_ToBeSynced;
            [modifiedItems addObject:oldNextItem];
        }
        
        ETA_ShoppingListItem* newNextItem = [self getListItemWithPreviousItemID:item.prevItemID inList:listID];
        if (newNextItem && [newNextItem.prevItemID isEqualToString:item.uuid]==NO)
        {
            newNextItem.prevItemID = item.uuid;
            newNextItem.modified = modified;
            newNextItem.state = ETA_DBSyncState_ToBeSynced;
            [modifiedItems addObject:newNextItem];
        }
    }
    
    NSMutableArray* objsToUpdate = [NSMutableArray new];
    [objsToUpdate addObjectsFromArray:modifiedItems];
    [objsToUpdate addObjectsFromArray:addedItems];
    BOOL success = [self updateDBObjects:objsToUpdate error:error];
    
    if (success)
    {
        [self sendNotificationOfLocalModified:modifiedItems
                                        added:addedItems
                                      removed:nil
                                     objClass:ETA_ShoppingListItem.class];
    }
    
    return success;
}

- (BOOL) removeListItem:(ETA_ShoppingListItem *)item error:(NSError * __autoreleasing *)error
{
    if (!item.uuid) {
        *error = [NSError errorWithDomain:kETA_ListManager_ErrorDomain
                                     code:ETA_ListManager_ErrorCode_MissingParameter
                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Can't remove non-existing list item",@"")}];
        return NO;
    }
    NSDate* modified = [NSDate date];
    NSString* listID = item.shoppingListID;
    
    NSMutableArray* objsToUpdate = [NSMutableArray array];

    item.modified = modified;
    item.state = ETA_DBSyncState_ToBeDeleted;
    [objsToUpdate addObject:item];
    
    // update the next item
    ETA_ShoppingListItem* nextItem = [self getListItemWithPreviousItemID:item.uuid inList:listID];
    if (nextItem && ![nextItem.uuid isEqualToString:item.uuid])
    {
        nextItem.prevItemID = item.prevItemID;
        nextItem.modified = modified;
        nextItem.state = ETA_DBSyncState_ToBeSynced;
        [objsToUpdate addObject:nextItem];
    }
    
    // if there is no sync-user for the objects, just delete them straight away. otherwise, mark as deleted
    BOOL success = NO;
    if (!item.syncUserID)
    {
        success = [self deleteDBObjects:@[item] error:error];
        if (nextItem && success)
            success = [self updateDBObjects:@[nextItem] error:error];
    }
    else
    {
        success = [self updateDBObjects:objsToUpdate error:error];
    }
    
    if (success)
    {
        [self sendNotificationOfLocalModified:(nextItem) ? @[nextItem] : nil
                                        added:nil
                                      removed:@[item]
                                     objClass:ETA_ShoppingListItem.class];
    }
    return success;
}


- (BOOL) removeAllListItemsInList:(NSString*)listID error:(NSError * __autoreleasing *)error
{
    ETA_ShoppingList* list = [self getList:listID];
    NSDate* modified = [NSDate date];
    
    NSArray* items = [self getAllListItemsInList:listID sortedByPreviousItemID:NO];
    
    // if there is no sync-user for the objects, just delete them straight away. otherwise, mark as deleted
    BOOL success = NO;
    if (list.syncUserID)
    {
        for (ETA_ShoppingListItem* item in items)
        {
            item.modified = modified;
            item.state = ETA_DBSyncState_ToBeDeleted;
        }
        success = [self updateDBObjects:items error:error];
    }
    else
    {
        success = [self deleteDBObjects:items error:error];
    }
    
    // mark the list as updated
    if (success)
    {
        [self updateList:list error:nil];
        
        [self sendNotificationOfLocalModified:nil
                                        added:nil
                                      removed:items
                                     objClass:ETA_ShoppingListItem.class];
    }
    return success;
}
- (BOOL) removeAllMarkedListItemsInList:(NSString*)listID error:(NSError * __autoreleasing *)error
{
    ETA_ShoppingList* list = [self getList:listID];
    NSDate* modified = [NSDate date];
    
    NSArray* items = [self getAllListItemsInList:listID sortedByPreviousItemID:NO];

    NSMutableDictionary* itemsToUpdateByUUID = [NSMutableDictionary dictionary];
    NSMutableDictionary* itemsToDeleteByUUID = [NSMutableDictionary dictionary];
    
    for (ETA_ShoppingListItem* item in items)
    {
        if (item.tick)
        {
            item.modified = modified;
            item.state = ETA_DBSyncState_ToBeDeleted;
            
            itemsToDeleteByUUID[item.uuid] = item;
            [itemsToUpdateByUUID removeObjectForKey:item.uuid];
            
            // update the next item
            ETA_ShoppingListItem* nextItem = [self getListItemWithPreviousItemID:item.uuid inList:listID];
            if (nextItem && ![nextItem.uuid isEqualToString:item.uuid] && !itemsToDeleteByUUID[nextItem.uuid])
            {
                nextItem.prevItemID = item.prevItemID;
                nextItem.modified = modified;
                nextItem.state = ETA_DBSyncState_ToBeSynced;
                itemsToUpdateByUUID[nextItem.uuid] = nextItem;
            }
        }
    }
    
    NSArray* allToDelete = itemsToDeleteByUUID.allValues;
    NSArray* allToUpdate = itemsToUpdateByUUID.allValues;
    
    // if there is no sync-user for the objects, just delete them straight away. otherwise, mark as deleted
    BOOL success = NO;
    if (list.syncUserID)
    {
        success = [self updateDBObjects:allToDelete error:error];
    }
    else
    {
        success = [self deleteDBObjects:allToDelete error:error];
    }
    
    if (success)
        [self updateDBObjects:allToUpdate error:nil];
    
    if (success)
    {
        [self sendNotificationOfLocalModified:allToUpdate
                                        added:nil
                                      removed:allToDelete
                                     objClass:ETA_ShoppingListItem.class];
    }
    return success;
}

- (ETA_ShoppingListItem*) getListItem:(NSString*)itemID
{
    return (ETA_ShoppingListItem*)[self getDBObjectWithUUID:itemID objClass:ETA_ShoppingListItem.class];
}

- (NSArray*) getAllListItemsWithNoPreviousItemIDInList:(NSString*)listID
{
    __block NSArray* items = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSMutableDictionary* WHERE = [@{kETA_ListItem_DBQuery_SyncState:[self activeSyncStates],
                                        kETA_ListItem_DBQuery_PrevItemID: NSNull.null,
                                        } mutableCopy];
        if (listID)
            [WHERE setValue:listID forKey:kETA_ListItem_DBQuery_ListID];
        
        items = [ETA_ShoppingListItem getAllItemsWhere:WHERE fromTable:[self localListItemsTableName] inDB:db];
    }];
    return items;
}
- (ETA_ShoppingListItem*) getListItemWithPreviousItemID:(NSString*)prevItemID inList:(NSString*)listID
{
    __block ETA_ShoppingListItem* item = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSMutableDictionary* WHERE = [@{kETA_ListItem_DBQuery_SyncState:[self activeSyncStates]} mutableCopy];
        if (listID)
            [WHERE setValue:listID forKey:kETA_ListItem_DBQuery_ListID];
        if (prevItemID)
            [WHERE setValue:prevItemID forKey:kETA_ListItem_DBQuery_PrevItemID];
        
        item = [[ETA_ShoppingListItem getAllItemsWhere:WHERE fromTable:[self localListItemsTableName] inDB:db] firstObject];
    }];
    return item;
}
- (ETA_ShoppingListItem*) getListItemWithOfferID:(NSString*)offerID inList:(NSString*)listID
{
    __block ETA_ShoppingListItem* item = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSMutableDictionary* WHERE = [@{kETA_ListItem_DBQuery_SyncState:[self activeSyncStates]} mutableCopy];
        if (listID)
            [WHERE setValue:listID forKey:kETA_ListItem_DBQuery_ListID];
        if (offerID)
            [WHERE setValue:offerID forKey:kETA_ListItem_DBQuery_OfferID];
        
        item = [[ETA_ShoppingListItem getAllItemsWhere:WHERE fromTable:[self localListItemsTableName] inDB:db] firstObject];
    }];
    return item;
}

- (NSArray*) getAllListItemsForUser:(NSString*)userID
{
    return [self getAllDBObjectsWithSyncStates:[self activeSyncStates]
                                       forUser:userID ?: NSNull.null
                                      objClass:ETA_ShoppingListItem.class];
}
- (NSArray*) getAllListItemsInList:(NSString*)listID sortedByPreviousItemID:(BOOL)sortedByPrev
{
    NSArray* items = [self getAllDBListItemsInList:listID withSyncStates:[self activeSyncStates]];
    
    if (!sortedByPrev || !items.count)
    {
        return items;
    }
    else
    {
        return [self sortListItemsByPrevItemID:items];
    }
}


- (NSArray*) sortListItemsByPrevItemID:(NSArray*)items
{
    NSMutableSet* allItemIDs = [NSMutableSet setWithCapacity:items.count];
    for (ETA_ShoppingListItem* item in items)
        [allItemIDs addObject:item.uuid];
    
    NSMutableDictionary* itemsByPrevItemID = [NSMutableDictionary dictionary];
    
    NSMutableArray* realFirstItems = [NSMutableArray array];
    NSMutableArray* orphanFirstItems = [NSMutableArray array];
    NSMutableArray* nilFirstItems = [NSMutableArray array];
    
    for (ETA_ShoppingListItem* item in items)
    {
        NSString* prevID = item.prevItemID;
        if (!prevID.length)
        {
            [nilFirstItems addObject:item];
        }
        else if ([prevID isEqualToString:kETA_ListManager_FirstPrevItemID])
        {
            [realFirstItems addObject:item];
        }
        else if (itemsByPrevItemID[prevID] == nil && [allItemIDs containsObject:prevID])
        {
            itemsByPrevItemID[prevID] = item;
        }
        else
        {
            [orphanFirstItems addObject:item];
        }
    }
    
    [realFirstItems sortedArrayUsingComparator:^NSComparisonResult(ETA_ShoppingListItem* item1, ETA_ShoppingListItem* item2) { return [item1.name caseInsensitiveCompare:item2.name]; }];
    [nilFirstItems sortedArrayUsingComparator:^NSComparisonResult(ETA_ShoppingListItem* item1, ETA_ShoppingListItem* item2) { return [item1.name caseInsensitiveCompare:item2.name]; }];
    [orphanFirstItems sortedArrayUsingComparator:^NSComparisonResult(ETA_ShoppingListItem* item1, ETA_ShoppingListItem* item2) { return [item1.name caseInsensitiveCompare:item2.name]; }];
    
    NSMutableArray* allFirstItems = [NSMutableArray arrayWithCapacity:realFirstItems.count + nilFirstItems.count + orphanFirstItems.count];
    [allFirstItems addObjectsFromArray:nilFirstItems];
    [allFirstItems addObjectsFromArray:realFirstItems];
    [allFirstItems addObjectsFromArray:orphanFirstItems];
    
    NSMutableArray* orderedItems = [NSMutableArray arrayWithCapacity:items.count];
    for (ETA_ShoppingListItem* firstItem in allFirstItems)
    {
        ETA_ShoppingListItem* nextItem = firstItem;
        while (nextItem)
        {
            [orderedItems addObject:nextItem];
            
            NSString* prevItemID = nextItem.uuid;
            
            // move on to the next item
            nextItem = itemsByPrevItemID[prevItemID];
            
            // clear from item dict
            [itemsByPrevItemID removeObjectForKey:prevItemID];
        }
    }
    
    // weird circular loop - sort this list
    if (itemsByPrevItemID.count)
    {
        [orderedItems addObjectsFromArray:itemsByPrevItemID.allValues];
    }
    
    return orderedItems;
}


#pragma mark - Local DB methods

- (NSString*) localListItemsTableName
{
    return @"listitems";
}
- (NSString*) localListsTableName
{
    return @"lists";
}
- (NSString*) localSharesTableName
{
    return @"shares";
}


- (NSArray*) activeSyncStates
{
    return @[@(ETA_DBSyncState_Synced), @(ETA_DBSyncState_Syncing), @(ETA_DBSyncState_ToBeSynced)];
}

- (void) localDBCreateTablesAt:(NSString*)dbFilePath
{

    [self.dbQ close];
    
    self.dbQ = [FMDatabaseQueue databaseQueueWithPath:dbFilePath];
    NSAssert(self.dbQ!=nil, @"There must be a valid local database!");
    
    __block NSInteger currentDBVersion = -1;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        
        FMResultSet *s = [db executeQuery:@"PRAGMA user_version"];
        if ([s next])
            currentDBVersion = [s intForColumnIndex:0];
        [s close];
    }];
    
    // delete and rebuild the file if it is out of date
    // TODO: some smart migration in the future
    if (currentDBVersion != kETA_ListManager_LatestDBVersion)
    {
        [self.dbQ close];
        self.dbQ = nil;
        NSError* err;
        [[NSFileManager defaultManager] removeItemAtPath:dbFilePath error:&err];
        self.dbQ = [FMDatabaseQueue databaseQueueWithPath:dbFilePath];
        NSAssert(self.dbQ!=nil, @"There must be a valid local database!");
    }
    
    
    [self.dbQ inDatabase:^(FMDatabase *db) {
        BOOL success = NO;
        
        success = [ETA_ShoppingListItem createTable:[self localListItemsTableName]
                                               inDB:db];
        if (!success) {
            [self log:@"Unable to create tables: %@", db.lastError];
            return;
        }
        
        success = [ETA_ShoppingList createTable:[self localListsTableName]
                                           inDB:db];
        if (!success){
            [self log:@"Unable to create tables: %@", db.lastError];
            return;
        }
        success = [ETA_ListShare createTable:[self localSharesTableName]
                                        inDB:db];
        if (!success) {
            [self log:@"Unable to create tables: %@", db.lastError];
            return;
        }
        // Note, can't be called in transaction
        [db executeUpdate:[NSString stringWithFormat:@"PRAGMA user_version = %d", kETA_ListManager_LatestDBVersion]];
    }];
}



#pragma mark - Syncr DB Handler protocol methods

- (BOOL) updateDBObjects:(NSArray*)objects error:(NSError * __autoreleasing *)error
{
    if (!objects.count)
        return YES;

    __block BOOL success = NO;
    [self.dbQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id object in objects)
        {
            if ([object isKindOfClass:ETA_ShoppingListItem.class])
            {
                success = [ETA_ShoppingListItem insertOrReplaceItem:(ETA_ShoppingListItem*)object
                                                          intoTable:[self localListItemsTableName]
                                                               inDB:db
                                                              error:error];
            }
            else if ([object isKindOfClass:ETA_ShoppingList.class])
            {
                success = [ETA_ShoppingList insertOrReplaceList:(ETA_ShoppingList*)object
                                                      intoTable:[self localListsTableName]
                                                           inDB:db
                                                          error:error];
            }
            else if ([object isKindOfClass:ETA_ListShare.class])
            {
                success = [ETA_ListShare insertOrReplaceShare:object
                                                    intoTable:[self localSharesTableName]
                                                         inDB:db
                                                        error:error];
            }
            if (!success) {
                *rollback = YES;
                return;
            }
        }
    }];
    return success;
}

- (BOOL) deleteDBObjects:(NSArray*)objects error:(NSError * __autoreleasing *)error
{
    if (!objects.count)
        return YES;
    
    __block BOOL success = NO;
    [self.dbQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id object in objects)
        {
            if ([object isKindOfClass:ETA_ShoppingListItem.class])
            {
                success = [ETA_ShoppingListItem deleteItem:((ETA_ShoppingListItem*)object).uuid
                                                 fromTable:[self localListItemsTableName]
                                                      inDB:db
                                                     error:error];
            }
            else if ([object isKindOfClass:ETA_ShoppingList.class])
            {
                success = [ETA_ShoppingList deleteList:((ETA_ShoppingList*)object).uuid
                                             fromTable:[self localListsTableName]
                                                  inDB:db
                                                 error:error];
                if (success)
                {
                    for (ETA_ListShare* share in ((ETA_ShoppingList*)object).shares)
                    {
                        success = [ETA_ListShare deleteShare:share
                                                   fromTable:[self localSharesTableName]
                                                        inDB:db
                                                       error:error];
                        if (!success)
                            break;
                    }
                }
            }
            else if ([object isKindOfClass:ETA_ListShare.class])
            {
                success = [ETA_ListShare deleteShare:(ETA_ListShare*)object
                                           fromTable:[self localSharesTableName]
                                                inDB:db
                                               error:error];
            }
            if (!success) {
                *rollback = YES;
                return;
            }
        }
    }];
    return success;
}

- (ETA_DBSyncModelObject*) getDBObjectWithUUID:(NSString*)objUUID objClass:(Class)objClass
{
    __block ETA_DBSyncModelObject* obj = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        if (objClass == ETA_ShoppingListItem.class)
        {
            obj = [ETA_ShoppingListItem getItemWithID:objUUID
                                            fromTable:[self localListItemsTableName]
                                                 inDB:db];
            
        }
        else if (objClass == ETA_ShoppingList.class)
        {
            obj = [ETA_ShoppingList getListWithID:objUUID
                                        fromTable:[self localListsTableName]
                                             inDB:db];
            
            // get the shares for the list
            if (obj)
            {
                ((ETA_ShoppingList*)obj).shares = [ETA_ListShare getAllSharesForList:objUUID
                                                                           fromTable:[self localSharesTableName]
                                                                                inDB:db];
            }
            
        }
    }];
    return obj;
}

// if userID is nil it will ignore the userID, while if NSNull.null it will get those without userID
- (NSArray*) getAllDBObjectsWithSyncStates:(NSArray*)syncStates forUser:(id)userID objClass:(Class)objClass
{
    __block NSArray* objs = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        if (objClass == ETA_ShoppingListItem.class)
        {
            NSMutableDictionary* WHERE = [NSMutableDictionary new];
            if (syncStates)
                [WHERE setValue:syncStates forKey:kETA_ListItem_DBQuery_SyncState];
            if (userID)
                [WHERE setValue:userID forKey:kETA_ListItem_DBQuery_UserID];
            
            objs = [ETA_ShoppingListItem getAllItemsWhere:WHERE fromTable:[self localListItemsTableName] inDB:db];
        }
        else if (objClass == ETA_ShoppingList.class)
        {
            objs = [ETA_ShoppingList getAllListsWithSyncStates:syncStates
                                                     andUserID:userID
                                                     fromTable:[self localListsTableName]
                                                          inDB:db];
            
            // get the shares for the list
            if (objs.count)
            {
                for (ETA_ShoppingList* list in objs)
                {
                    list.shares = [ETA_ListShare getAllSharesForList:list.uuid
                                                           fromTable:[self localSharesTableName]
                                                                inDB:db];
                }
            }
        }
        else if (objClass == ETA_ListShare.class)
        {
            objs = [ETA_ListShare getAllSharesWithSyncStates:syncStates
                                                   andUserID:userID
                                                   fromTable:[self localSharesTableName]
                                                        inDB:db];
        }
    }];
    return objs;
}


- (NSArray*) getAllDBListItemsInList:(NSString*)listID withSyncStates:(NSArray*)syncStates
{
    __block NSArray* items = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        NSMutableDictionary* WHERE = [NSMutableDictionary new];
        if (syncStates)
            [WHERE setValue:syncStates forKey:kETA_ListItem_DBQuery_SyncState];
        if (listID)
            [WHERE setValue:listID forKey:kETA_ListItem_DBQuery_ListID];
        
        items = [ETA_ShoppingListItem getAllItemsWhere:WHERE fromTable:[self localListItemsTableName] inDB:db];
    }];
    return items;
}

- (NSArray*) getAllDBSharesInList:(NSString*)listID
{
    __block NSArray* shares = nil;
    [self.dbQ inDatabase:^(FMDatabase *db) {
        shares =  [ETA_ListShare getAllSharesForList:listID fromTable:[self localSharesTableName] inDB:db];
    }];
    return shares;
}


#pragma mark - Utilities

- (void) setVerbose:(BOOL)verbose
{
    _verbose = verbose;
    
    self.syncr.verbose = verbose;
}

- (void) log:(NSString*)format, ...
{
    if (!self.verbose)
        return;
    
    va_list args;
    va_start(args, format);
    NSString* msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"[ETA_ListManager] %@", msg);
}


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
