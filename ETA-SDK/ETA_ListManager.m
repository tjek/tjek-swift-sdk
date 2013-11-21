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


NSString* const ETA_ListManager_ChangeNotification_Lists = @"ETA_ListManager_ChangeNotification_ServerLists";
NSString* const ETA_ListManager_ChangeNotification_ListItems = @"ETA_ListManager_ChangeNotification_ServerListItems";

NSString* const ETA_ListManager_ChangeNotificationInfo_FromServerKey = @"fromServer";
NSString* const ETA_ListManager_ChangeNotificationInfo_ModifiedKey = @"modified";
NSString* const ETA_ListManager_ChangeNotificationInfo_AddedKey = @"added";
NSString* const ETA_ListManager_ChangeNotificationInfo_RemovedKey = @"removed";


NSString* const kETA_ListManager_ErrorDomain = @"ETA_ListManager_ErrorDomain";
NSString* const kETA_ListManager_FirstPrevItemID = @"00000000-0000-0000-0000-000000000000";
NSInteger const kETA_ListManager_LatestDBVersion = 2;

@interface ETA_ListManager ()<ETA_ListSyncrDBHandlerProtocol>

@property (nonatomic, strong) ETA_ListSyncr* syncr;

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
    }
}


- (void) syncr_listsChangedNotification:(NSNotification*)notification
{
    NSDictionary* syncrChanges = notification.userInfo;
    
    NSArray* added = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_AddedKey];
    NSArray* modified = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey];
    NSArray* removed = syncrChanges[ETA_ListSyncr_ChangeNotificationInfo_RemovedKey];
    
    
//    
//    // WHY!!!
//    NSMutableArray* itemsToUpdate = [NSMutableArray array];
//    NSDate* modifiedDate = [NSDate date];
//    
//    NSArray* listsToBeSorted = [added ?: @[] arrayByAddingObjectsFromArray:modified];
//    // clean up prev item IDs
//    for (ETA_ShoppingList* list in listsToBeSorted)
//    {
//        NSArray* sortedItems = [self getAllListItemsInList:list.uuid sortedByPreviousItemID:YES];
//        
//        NSString* nextPrevItemID = kETA_ListManager_FirstPrevItemID;
//        for (ETA_ShoppingListItem* item in sortedItems)
//        {
//            if ([item.prevItemID isEqualToString:nextPrevItemID] == NO)
//            {
//                item.prevItemID = nextPrevItemID;
//                item.modified = modifiedDate;
//                item.state = ETA_DBSyncState_ToBeSynced;
//                [itemsToUpdate addObject:item];
//            }
//            nextPrevItemID = item.uuid;
//        }
//    }
//    if (itemsToUpdate.count)
//    {
//        [self log:@"Lists Modified - resorting items. %d had modified prevItemIDs", itemsToUpdate.count];
//        
//        NSError* err = nil;
//        if (![self updateDBObjects:itemsToUpdate error:&err])
//        {
//            [self log:@"Failed to update the prevItemIDs of re-sorted Items %d:%@", err.code, err.localizedDescription];
//        }
//    }
    
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
    return self.syncr ? self.syncr.pollRate : ETA_ListManager_SyncRate_None;
}




#pragma mark - Public methods

#pragma mark Lists
- (ETA_ShoppingList*) createShoppingList:(NSString*)name
                                 forUser:(NSString*)userID
                                   error:(NSError * __autoreleasing *)error
{
    NSString* uuid = [[self class] generateUUID];
    
    ETA_ShoppingList* list = [ETA_ShoppingList shoppingListWithUUID:uuid
                                                               name:name
                                                       modifiedDate:nil
                                                             access:ETA_ShoppingList_Access_Private];
    list.syncUserID = userID;
    
    BOOL success = [self addList:list error:error];
    
    return (success) ? list : nil;
}

- (ETA_ShoppingList*) createWishList:(NSString*)name
                             forUser:(NSString*)userID
                               error:(NSError * __autoreleasing *)error
{
    
    NSString* uuid = [[self class] generateUUID];
    
    ETA_ShoppingList* list = [ETA_ShoppingList wishListWithUUID:uuid
                                                           name:name
                                                   modifiedDate:nil
                                                         access:ETA_ShoppingList_Access_Private];
    list.syncUserID = userID;
    
    
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
        NSMutableDictionary* itemsByPrevItemID = [NSMutableDictionary dictionary];
        
        NSMutableArray* firstItems = [NSMutableArray array];
        NSMutableArray* orderedItems = [NSMutableArray new];
        
        for (ETA_ShoppingListItem* item in items)
        {
            NSString* prevID = item.prevItemID;
            if (prevID)
            {
                if ([prevID isEqualToString:kETA_ListManager_FirstPrevItemID])
                    [firstItems addObject:item];
                else if (!itemsByPrevItemID[prevID])
                    itemsByPrevItemID[prevID] = item;
                else
                    [orderedItems addObject:item];
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
        if (!success)
            return;
        success = [ETA_ShoppingList createTable:[self localListsTableName]
                                           inDB:db];
        if (!success)
            return;
        
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
