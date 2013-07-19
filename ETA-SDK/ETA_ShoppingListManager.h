//
//  ETA_ShoppingListManager.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/15/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const ETA_ShoppingListManager_ListsChangedNotification;
extern NSString* const ETA_ShoppingListManager_ItemsChangedNotification;

@class ETA;
@class ETA_ShoppingList;
@interface ETA_ShoppingListManager : NSObject

+ (instancetype) managerWithETA:(ETA*)eta;


#pragma mark - Polling
@property (nonatomic, readwrite, assign) NSTimeInterval pollInterval; // changing the pollInterval while polling will trigger a restart
@property (nonatomic, readonly, assign) BOOL isPolling;
- (void) startPollingServer;
- (void) stopPollingServer;


// creates a new shopping list with 'name' and calls addShoppingList:
- (void) createShoppingList:(NSString*)name;

// try to add the list to both the local store and the server
- (void) addShoppingList:(ETA_ShoppingList*)newList;



// create a new shopping list (if user logged in) and send request to server
// mark list as not-synced, and if request succeeds mark as synced.
// send 'listAdded' notification



// if this is true, queries will act as if there is no user attached to the session
// use this if you want to get the state of the userless shopping lists after a user has logged in
@property (nonatomic, readwrite, assign) BOOL ignoreSessionUser;

//
//// go to the server and get the latest state of all the shopping lists.
//// does not use the cache.
//- (void) fetchAllShoppingListsForUser:(NSString*)userID completion:(void (^)(NSArray* lists, NSError* error))completionHandler;
//
//// get the latest modified date for the specified shopping list
//- (void) fetchShoppingList:(NSString*)listID modifiedDateForUser:(NSString*)userID completion:(void (^)(NSDate* modifiedDate, NSError* error))completionHandler;


// the shopping list to use if there is no user
@property (nonatomic, readonly, strong) ETA_ShoppingList* loggedOutShoppingList;

// the userID for the shopping lists. nil if there is no connected users
@property (nonatomic, readonly, strong) NSString* userID;
// the shopping lists to use when the user is signed in
@property (nonatomic, readonly, strong) NSArray* userShoppingLists;

//// take the changes from the 'updatedList' and modify the list locally. Also send request to server
//// mark list as not synced, and if request succeeds mark as synced.
//// send 'listChanged' notification
//- (void) updateShoppingList:(NSString*)listUUID name:(NSString*)name;
////- (void) updateShoppingList:(ETA_ShoppingList*)updatedList;
//
//// remove the list locally. Send request to server.
//// save timestamped request. If server succeeds remove request.
//- (void) removeShoppingList:(NSString*)listUUID;
//
//
//- (void) shareShoppingList:(NSString*)listUUID withUser:(NSString*)email properties:(NSDictionary*)properties;
//
//// poll the server for changes to the shopping lists.
//// triggered every 6 secs
//// sends listChanged and itemChanged notifications
//- (void) checkForUpdates;




// will remove the items from 'fromList' and add them to 'toList'
//- (void) moveItemsFrom:(ETA_ShoppingList*)fromList to:(ETA_ShoppingList*)toList;


#pragma mark - Lists
- (void) getShoppingLists:(void (^)(NSArray* shoppingLists, NSError* error))completionHandler;
- (void) createShoppingList:(NSString*)listUUID
             withProperties:(NSDictionary*)listProperties
                 completion:(void (^)(ETA_ShoppingList* list, NSError* error))completionHandler;

- (void) deleteShoppingList:(NSString*)listUUID
                 completion:(void (^)(NSError* error))completionHandler;
- (void) getShoppingListModifiedDate:(NSString*)listUUID
                          completion:(void (^)(NSDate* modifiedDate, NSError* error))completionHandler;
- (void) getShoppingListShares:(NSString*)listUUID
                    completion:(void (^)(NSArray* users, NSError* error))completionHandler;
- (void) shareShoppingList:(NSString*)listUUID
                  withUser:(NSString*)email
                properties:(NSDictionary*)properties
                completion:(void (^)(id response, NSError* error))completionHandler;

#pragma mark - Items
- (void) getShoppingListItemsForShoppingList:(NSString*)listUUID
                                  completion:(void (^)(NSArray* shoppingListItems, NSError* error))completionHandler;
- (void) createShoppingListItem:(NSString*)itemUUID
                 withProperties:(NSDictionary*)itemProperties
                 inShoppingList:(NSString*)listUUID
                     completion:(void (^)(id item, NSError* error))completionHandler;
- (void) deleteShoppingListItem:(NSString *)itemUUID
                     completion:(void (^)(NSError *))completionHandler;
- (void) deleteAllShoppingListItemsFromShoppingList:(NSString *)listUUID
                                             filter:(NSString*)filter
                                         completion:(void (^)(NSError *))completionHandler;


#pragma mark - Permissions
- (BOOL) canReadShoppingLists;
- (BOOL) canWriteShoppingLists;



@end
