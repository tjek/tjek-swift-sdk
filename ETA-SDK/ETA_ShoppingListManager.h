//
//  ETA_ShoppingListManager.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ETA;
@class ETA_ShoppingList;
@class ETA_ShoppingListItem;


extern NSString* const ETA_ShoppingListManager_ListsChangedNotification;
extern NSString* const ETA_ShoppingListManager_ItemsChangedNotification;
extern NSString* const ETA_ShoppingListManager_ItemsUpdatedNotification;
extern NSString* const ETA_ShoppingListManager_ItemsRemovedNotification;
extern NSString* const ETA_ShoppingListManager_ItemsAddedNotification;

extern NSString* const kETA_ShoppingListManager_FirstPrevItemID;

typedef enum {
    ETA_ShoppingListItemFilter_All = 0,
    ETA_ShoppingListItemFilter_Ticked = 1,
    ETA_ShoppingListItemFilter_Unticked = 2,
} ETA_ShoppingListItemFilter;

typedef enum{
    ETA_ShoppingListManager_PollRate_Default = 0,
    ETA_ShoppingListManager_PollRate_Fast = 1,
    ETA_ShoppingListManager_PollRate_Slow = 2,
    ETA_ShoppingListManager_PollRate_None = 3,
} ETA_ShoppingListManager_PollRate;


/**
 *	All actions with regard to shopping lists and their items should occur through the ETA_ShoppingListManager.
 *
 *  It takes care of keeping a local store of ETA_ShoppingList and ETA_ShoppingListItem objects in sync with the server, even when offline.
 */
@interface ETA_ShoppingListManager : NSObject



#pragma mark - Setup
///---------------------------------------------
/// @name Setup
///---------------------------------------------
/**
 *	An shared instance of the Shopping List Manager, that uses *ETA.SDK* for session and user management.
 *
 *  @warn This will return nil if you haven't called `+initializeWith...` for the ETA.SDK singleton.
 *
 *	@return	A shared instance of the Shopping List Manager
 *
 *  @see +managerWithETA:
 */
+ (instancetype) sharedManager;


/**
 *	Create an instance of the Shopping List Manager.
 *
 *	@param	eta	The `ETA` object that will be used for user management. If nil the shopping list manager will only work offline.
 *
 *	@return	The newly created Shopping List Manager
 */
+ (instancetype) managerWithETA:(ETA*)eta;


/**
 *	This is how regularly we should ask the server for item/list changes. It can be `Default`, `Slow`, or `Off`.
 */
@property (nonatomic, readwrite, assign) ETA_ShoppingListManager_PollRate pollRate;



#pragma mark - Shopping Lists
///---------------------------------------------
/// @name Shopping Lists
///---------------------------------------------

/**
 *	Creates a new `ETA_ShoppingList` with the specified 'name' and a unique ID, and calls -addShoppingList:completion:.
 *
 *	@param	name	The name to be given to the list. Name must not be nil.
 *	@param	completionHandler	Called on the main queue when the shopping list is first added to the local store, and then when the server sends a response (the `fromServer` flag lets you know which event triggered the callback). May only be called once if unable to send server request. When *fromServer == NO* the `list` object is the object that was sent to the server, otherwise it is the parsed response from the server. If something went wrong `error` will be non-nil. If the server responds with a non-network related error (eg. invalid data was sent), this will return with an error. If it was a networking issue, however, we will keep retrying until it is sent. Unfortunately, you will not recieve a completion handler 
 *
 *  @see -addShoppingList:completion:
 */
- (void) createShoppingList:(NSString*)name
                 completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler;
- (void) createWishList:(NSString*)name
             completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler;

/**
 *	Tries to add an `ETA_ShoppingList` object to both the local store and the server.
 *
 *  If a list with this uuid already exists the changes will be saved.
 *
 *	@param	list	The list object to be added. The list must have a valid name and uuid.
 *	@param	completionHandler	Called on the main queue when the shopping list is first added to the local store, and then when the server sends a response (the `fromServer` flag lets you know which event triggered the callback). May only be called once if unable to send server request. When *fromServer == NO* the `list` object is the object that was sent to the server, otherwise it is the parsed response from the server. If something went wrong `error` will be non-nil.
 *
 *  @see -updateShoppingList:completion:
 */
- (void) addShoppingList:(ETA_ShoppingList*)list
              completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler;


/**
 *	Tries to remove the shopping list object from both the local store and the server.
 *
 *	@param	list	The list object to be removed. The list must have a valid uuid.
 *	@param	completionHandler   Called on the main queue when the shopping list is first removed from the local store, and then when the server sends a response (the `fromServer` flag lets you know which event triggered the callback). May only be called once if unable to send server request. If something went wrong `error` will be non-nil.
 */
- (void) removeShoppingList:(ETA_ShoppingList*)list
                 completion:(void (^)(NSError* error, BOOL fromServer))completionHandler;
- (void) removeShoppingList:(ETA_ShoppingList*)list;

/**
 *	Save the changes in 'list' to local store and server.
 *
 *  This will add the list if it doesnt exist.
 *
 *	@param	list	The new state of the list to be saved. The uuid will be used to find the list. The list must have a valid uuid.
 *	@param	completionHandler	Called on the main queue when the shopping list is first updated in the local store, and then when the server sends a response (the `fromServer` flag lets you know which event triggered the callback). May only be called once if unable to send server request. When *fromServer == NO* the `list` object is the object that was sent to the server, otherwise it is the parsed response from the server. If something went wrong `error` will be non-nil.
 *
 *  @see -addShoppingList:completion:
 */
- (void) updateShoppingList:(ETA_ShoppingList*)list
                 completion:(void (^)(ETA_ShoppingList* list, NSError* error, BOOL fromServer))completionHandler;


/**
 *	Get the shopping list with the specified `listID` from the local store
 *
 *	@param	listID	The `uuid` of the list to be returned
 *
 *	@return	The list object matching the `listID`, taken from the local store. Returns `nil` if not found.
 */
- (ETA_ShoppingList*) getShoppingList:(NSString*)listID;


/**
 *	Get an array of all the shopping lists from the local store
 *
 *	@return	An array of all the `ETA_ShoppingList` objects in the local store.
 */
- (NSArray*) getAllShoppingLists;





#pragma mark - Shopping List Items

// creates a new item with 'name' in 'listID' and calls addShoppingListItem:
- (void) createShoppingListItem:(NSString *)name offerID:(NSString*)offerID inList:(NSString*)listID completion:(void (^)(ETA_ShoppingListItem* item, NSError* error, BOOL fromServer))completionHandler;

// try to add the item to both the local store and the server
- (void) addShoppingListItem:(ETA_ShoppingListItem *)item completion:(void (^)(ETA_ShoppingListItem* item, NSError* error, BOOL fromServer))completionHandler;

// remove the specified item from both the local store and the sever
- (void) removeShoppingListItem:(ETA_ShoppingListItem *)item completion:(void (^)(ETA_ShoppingListItem* item, NSError* error))completionHandler;

// remove all the items in 'list that match the filter from both the local store and the sever
- (void) removeAllShoppingListItemsFromList:(ETA_ShoppingList*)list filter:(ETA_ShoppingListItemFilter)filter;

// save the changes in 'item' to local store and server
- (void) updateShoppingListItem:(ETA_ShoppingListItem*)item completion:(void (^)(ETA_ShoppingListItem* item, NSError* error, BOOL fromServer))completionHandler;


// return the shopping list item with the specified itemID from the local store
// nil if not found
- (ETA_ShoppingListItem*) getShoppingListItem:(NSString*)itemID;

// return a list of all the shopping list items from the local store
- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID;

// return the shopping list item with the specifed offer id from within the specified list
- (ETA_ShoppingListItem*) getShoppingListItemWithOfferID:(NSString*)offerID inList:(NSString*)listID;

// return a list of all the shopping list items from the local store that match the filter
- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter;


- (void) reorderItems:(NSArray*)items;


// if this is true, queries will act as if there is no user attached to the session
// use this if you want to get the state of the userless shopping lists after a user has logged in
@property (nonatomic, readwrite, assign) BOOL ignoreAttachedUser;

// whether the shopping list manager logs errors and events. Defaults to NO.
@property (nonatomic, readwrite, assign) BOOL verbose;

#pragma mark - Permissions

// does the current session support the attached user reading and writing shopping lists
// returns YES if no attached user
- (BOOL) canReadShoppingLists;
- (BOOL) canWriteShoppingLists;

@property (nonatomic, readonly, strong) NSString* userID;

@end
