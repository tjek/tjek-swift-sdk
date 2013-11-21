//
//  ETA_ListSyncr.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ETA;
@class FMDatabaseQueue;
@class ETA_DBSyncModelObject;

extern NSString* const ETA_ListSyncr_ChangeNotification_Lists;
extern NSString* const ETA_ListSyncr_ChangeNotification_ListItems;
extern NSString* const ETA_ListSyncr_ChangeNotificationInfo_ModifiedKey;
extern NSString* const ETA_ListSyncr_ChangeNotificationInfo_AddedKey;
extern NSString* const ETA_ListSyncr_ChangeNotificationInfo_RemovedKey;

typedef enum{
    ETA_ListSyncr_PollRate_None = 0,
    ETA_ListSyncr_PollRate_Slow = 1,
    ETA_ListSyncr_PollRate_Default = 2,
} ETA_ListSyncr_PollRate;

@protocol ETA_ListSyncrDBHandlerProtocol <NSObject>

@required

- (BOOL) updateDBObjects:(NSArray*)objects error:(NSError * __autoreleasing *)error;
- (BOOL) deleteDBObjects:(NSArray*)objects error:(NSError * __autoreleasing *)error;

- (ETA_DBSyncModelObject*) getDBObjectWithUUID:(NSString*)objUUID objClass:(Class)objClass;
- (NSArray*) getAllDBObjectsWithSyncStates:(NSArray*)syncStates forUser:(id)userID objClass:(Class)objClass;

- (NSArray*) getAllDBListItemsInList:(NSString*)listID withSyncStates:(NSArray*)syncStates;

@end

@interface ETA_ListSyncr : NSObject

+ (instancetype) syncrWithETA:(ETA*)eta localDBQueryHandler:(id<ETA_ListSyncrDBHandlerProtocol>)dbHandler;

/**
 *	This is how regularly we should ask the server for item/list changes. It can be `Default`, `Slow`, or `Off`.
 */
@property (nonatomic, readwrite, assign) ETA_ListSyncr_PollRate pollRate;


@property (nonatomic, readwrite, assign) BOOL verbose;

@property (atomic, readonly, assign) BOOL syncingInProgress;

@end
