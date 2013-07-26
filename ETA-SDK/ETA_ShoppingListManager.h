//
//  ETA_ShoppingListManager.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const ETA_ShoppingListManager_ListsChangedNotification;
extern NSString* const ETA_ShoppingListManager_ItemsChangedNotification;

typedef enum {
    ETA_ShoppingListItemFilter_All = 0,
    ETA_ShoppingListItemFilter_Ticked = 1,
    ETA_ShoppingListItemFilter_Unticked = 2,
} ETA_ShoppingListItemFilter;

typedef enum{
    ETA_ShoppingListManager_PollRate_Default = 0,
    ETA_ShoppingListManager_PollRate_Rapid = 1,
    ETA_ShoppingListManager_PollRate_Slow = 2,
    ETA_ShoppingListManager_PollRate_None = 3,
} ETA_ShoppingListManager_PollRate;


@class ETA;
@class ETA_ShoppingList;
@class ETA_ShoppingListItem;
@interface ETA_ShoppingListManager : NSObject

+ (instancetype) managerWithETA:(ETA*)eta;


// This is how regularly we should ask the server for item/list changes
// It can be default, rapid, slow, or off.
@property (nonatomic, readwrite, assign) ETA_ShoppingListManager_PollRate pollRate;



#pragma mark - Shopping Lists

// creates a new shopping list with 'name' and calls addShoppingList:
- (ETA_ShoppingList*) createShoppingList:(NSString*)name;

// try to add the list to both the local store and the server
- (void) addShoppingList:(ETA_ShoppingList*)list;

// try to remove the shopping list from both the local store and the server
- (void) removeShoppingList:(ETA_ShoppingList*)list;

// save the changes in 'list' to local store and server (will also add the list if it doesnt exist)
- (void) updateShoppingList:(ETA_ShoppingList*)list;


// return the shopping list with the specified listID from the local store
// nil if not found
- (ETA_ShoppingList*) getShoppingList:(NSString*)listID;

// return a list of all the shopping lists from the local store
- (NSArray*) getAllShoppingLists;





#pragma mark - Shopping List Items

// creates a new item with 'name' in 'listID' and calls addShoppingListItem:
- (ETA_ShoppingListItem *) createShoppingListItem:(NSString *)name inList:(NSString*)listID;

// try to add the item to both the local store and the server
- (void) addShoppingListItem:(ETA_ShoppingListItem *)item;

// remove the specified item from both the local store and the sever
- (void) removeShoppingListItem:(ETA_ShoppingListItem *)item;

// remove all the items in 'list that match the filter from both the local store and the sever
- (void) removeAllShoppingListItemsFromList:(ETA_ShoppingList*)list filter:(ETA_ShoppingListItemFilter)filter;

// save the changes in 'item' to local store and server
- (void) updateShoppingListItem:(ETA_ShoppingListItem*)item;


// return the shopping list item with the specified itemID from the local store
// nil if not found
- (ETA_ShoppingListItem*) getShoppingListItem:(NSString*)itemID;

// return a list of all the shopping list items from the local store
- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID;

// return a list of all the shopping list items from the local store that match the filter
- (NSArray*) getAllShoppingListItemsInList:(NSString*)listID withFilter:(ETA_ShoppingListItemFilter)filter;







// if this is true, queries will act as if there is no user attached to the session
// use this if you want to get the state of the userless shopping lists after a user has logged in
@property (nonatomic, readwrite, assign) BOOL ignoreAttachedUser;


#pragma mark - Permissions

// does the current session support the attached user reading and writing shopping lists
// returns YES if no attached user
- (BOOL) canReadShoppingLists;
- (BOOL) canWriteShoppingLists;


@end
