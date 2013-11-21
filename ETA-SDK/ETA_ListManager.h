//
//  ETA_ListManager.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ETA;
@class ETA_ShoppingList;
@class ETA_ShoppingListItem;


extern NSString* const ETA_ListManager_ChangeNotification_Lists;
extern NSString* const ETA_ListManager_ChangeNotification_ListItems;
extern NSString* const ETA_ListManager_ChangeNotificationInfo_FromServerKey;
extern NSString* const ETA_ListManager_ChangeNotificationInfo_ModifiedKey;
extern NSString* const ETA_ListManager_ChangeNotificationInfo_AddedKey;
extern NSString* const ETA_ListManager_ChangeNotificationInfo_RemovedKey;


extern NSString* const kETA_ListManager_ErrorDomain;
extern NSString* const kETA_ListManager_FirstPrevItemID;

typedef enum {
    ETA_ListManager_SyncRate_None = 0,
    ETA_ListManager_SyncRate_Slow = 1,
    ETA_ListManager_SyncRate_Default = 2,
} ETA_ListManager_SyncRate;

typedef enum {
    ETA_ListManager_ErrorCode_MissingParameter = 0
} ETA_ListManager_ErrorCode;

@interface ETA_ListManager : NSObject

#pragma mark - Setup
///---------------------------------------------
/// @name Setup
///---------------------------------------------
/**
 *	An shared instance of the List Manager, that uses *ETA.SDK* for syncing & user management, and the default local database path.
 *
 *  @warn This will return nil if you haven't called `+initializeWith...` for the ETA.SDK singleton.
 *
 *	@return	A shared instance of the List Manager
 *
 *  @see +managerWithETA:
 */
+ (instancetype) sharedManager;


/**
 *	Create an instance of the List Manager.
 *
 *	@param	eta	The `ETA` object that will be used for syncing to the server, and for user management. If nil the list manager will only work offline.
 *
 *  @param  localDBFilePath The path and filename of the local SQLite database file. If nil a default path is used. Will assert if path is invalid.
 *
 *	@return	The newly created Shopping List Manager
 */
+ (instancetype) managerWithETA:(ETA*)eta localDBFilePath:(NSString*)localDBFilePath;


/**
 *  How regularly we should send and receive changes to/from the ETA sdk.
 *
 *  @warn This is directly passed through to the ListSyncr obj's pollRate. If no ETA object specified, this will return ETA_ListManager_SyncRate_None;
 */
@property (nonatomic, readwrite, assign) ETA_ListManager_SyncRate syncRate;

/**
 * Whether the List manager logs errors and events. Defaults to NO.
 */
@property (nonatomic, readwrite, assign) BOOL verbose;



#pragma mark - Lists
///---------------------------------------------
/// @name Lists
///---------------------------------------------

- (ETA_ShoppingList*) createShoppingList:(NSString*)name
                                 forUser:(NSString*)userID
                                   error:(NSError * __autoreleasing *)error;

- (ETA_ShoppingList*) createWishList:(NSString*)name
                             forUser:(NSString*)userID
                               error:(NSError * __autoreleasing *)error;


- (BOOL) addList:(ETA_ShoppingList*)list error:(NSError * __autoreleasing *)error;
- (BOOL) updateList:(ETA_ShoppingList*)list error:(NSError * __autoreleasing *)error;
- (BOOL) removeList:(ETA_ShoppingList*)list error:(NSError * __autoreleasing *)error;


- (ETA_ShoppingList*) getList:(NSString*)listID;
- (NSArray*) getAllListsForUser:(NSString*)userID;


#pragma mark - List Items
///---------------------------------------------
/// @name List Items
///---------------------------------------------

- (ETA_ShoppingListItem*) createListItem:(NSString *)name
                                 offerID:(NSString*)offerID
                            creatorEmail:(NSString*)creatorEmail
                                  inList:(NSString*)listID
                                   error:(NSError * __autoreleasing *)error;

- (BOOL) addListItem:(ETA_ShoppingListItem *)item error:(NSError * __autoreleasing *)error;
- (BOOL) updateListItem:(ETA_ShoppingListItem *)item error:(NSError * __autoreleasing *)error;
- (BOOL) removeListItem:(ETA_ShoppingListItem *)item error:(NSError * __autoreleasing *)error;
- (BOOL) removeAllListItemsInList:(NSString*)listID error:(NSError * __autoreleasing *)error;
- (BOOL) removeAllMarkedListItemsInList:(NSString*)listID error:(NSError * __autoreleasing *)error;

- (ETA_ShoppingListItem*) getListItem:(NSString*)itemID;
- (ETA_ShoppingListItem*) getListItemWithPreviousItemID:(NSString*)prevItemID inList:(NSString*)listID;
- (ETA_ShoppingListItem*) getListItemWithOfferID:(NSString*)offerID inList:(NSString*)listID;

- (NSArray*) getAllListItemsForUser:(NSString*)userID;
- (NSArray*) getAllListItemsInList:(NSString*)listID sortedByPreviousItemID:(BOOL)sortedByPrev;


@end
