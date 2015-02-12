# List Manager

> **Note:** You must first [initialise the SDK](GettingStarted.md#configure-the-sdk) before using the List Manager.


In order to use the List Manager you must add the following dependency to your Podfile:

`pod 'ETA-SDK/ListManager'`

This will automatically add the `ETA-SDK/API` component as a dependency to your project as well.

 
## Usage

The world of Shopping Lists is a lot more complex than any of the other parts of the new API, so we provide the `ETA_ListManager` through which all ShoppingList related communication should happen.


To include the `ETA_ListManager` in your code you must import the header file:

```obj-c 
#import <ETA-SDK/ETA_ListManager.h>
```


To access the list manager it is best to simply use the ListManager singleton `[ETA_ListManager sharedManager]`. This will create a local sqlite database file called '*local_lists.db*'.

If you wish to use a different database file, or instance of ETA, you can create a ListManager with `+managerWithETA:localDBFilePath:`, passing in the `ETA` SDK object and the full path the database file. Although multiple instances of the ListManager _should_ work, it is untested.

### Polling & Syncing

The main job of the manager is keeping a local store of `ETA_ShoppingList` and `ETA_ShoppingListItem` objects in sync with the the server. It does this by polling the server at a regular interval for changes to the lists and items.

When something changes a notification will be triggered (see **[Notifications](#notifications)** section below).

You can change the rate of this polling using the `syncRate` property (for example, perhaps you want to slow down or stop the polling when not looking at the shopping lists).

##### Attached User
One major thing to note is that the behaviour of the `ETA_ListManager` is closely tied to the `ETA` object's `attachedUser` property (so if you create the manager manually and pass nil for the SDK you will only work locally). 

If there is no attached user, the manager will not be able to sync changes to the server, and so will not poll, and all changes you make will be saved to a 'userless' local store. As soon as a user is attached (by logging in) the changes that are now made will be saved to a 'user' local store, and also sent to the server. 

It is your responsibility to merge any changes from the 'userless' local store to server (perhaps asking the user which of their online lists they want to move the userless items to). You should also remove old user data when the user changes. To help with this migration there are a couple of methods change the ownership of lists and their items:

```obj-c
// use `nil` to refer to the user-less user
- (BOOL) moveListsFromUser:(ETA_User*)fromUser 
					toUser:(ETA_User*)toUser 
					 error:(NSError * __autoreleasing *)error;

// use NSNull.null to refer to the user-less user, and `nil` to refer to _all_ users
// (I know, I know, this needs to be cleaned up!)
- (BOOL) dropAllDataForUserID:(id)userID 
						error:(NSError * __autoreleasing *)error;
```

##### Failure handling
The server is always considered the truth when it comes to syncing. However, if there are changes on the client side we will not poll and ask the server for it's state until all those changes are successfully sent. 

Great effort has been made to make sure that if something goes wrong while sending a change request to the server it will not be lost. It will retry a number of times, and if that fails it will enter a slow retry cycle (this would happen if the app has gone offline). If the app shuts down before the changes are sent, when the manager starts again and logs in with the same user we will retry sending the changes before we start polling again. 

This may cause a problem if the user logs in with a different userID before the local changes for the previous user are sent. This is because there is only one local store for all users, and this is cleared and replaced with the server state when a different user logs in. Logging off and on with the same user will not be a problem.


### Methods

There are multiple `ETA_ShoppingList` and `ETA_ShoppingListItem` variants for each of the following methods:

##### `-get…`
All of the getters will give you the results from the local store, as up to date with the server as the last poll.

The objects that are returned by the getters are copies - changing properties will have no effect on the local store or server unless you pass the object back to one of the setter methods.

##### `-create…`
Initializes an object with a new `uuid`, calls the related `-add…` method, and returns the newly created object. Returns `nil` if it couldn't create the object.

##### `-add…`
This will actually just call `-update:`, but is useful for being explicit about your intentions.

##### `-update…`
If the passed in object doesn't exist in the local store (based on `uuid`) this will add it, and if a user is logged in it will try to send the request to server.

If the object already exists in the local store then the local store will be updated to use the values in the passed in object, and if a user is logged in it will send a request to update the object's properties on the server.

Before adding or updating, the object's `modified` date will be updated to the current date and time.

A notification will be triggered containing the object (see **[Notifications](#notifications)** section below). 

You would use this method whenever you change a property on an object (for example when ticking a shopping list item).

##### `-remove…` 
Removing an object will mark it as needing to be deleted from the local store, and send a delete request to the server. Only when the object is successfully deleted from the server is the object removed from the local store. Obviously, if there is no user logged in it is instantly removed from the local store.

A notification will be triggered containing the deleted object (see **[Notifications](#notifications)** section below). 

When removing a shopping list, all the items in that list will also be removed from the local store (the server will automatically take care of removing these orphaned items from the server). It will, however, only send a notification about the removal of the list, not the items.


### Notifications

Everytime something is changed, either by the server or locally, a notification is sent to `NSNotificationCenter`.

There are two notifications you can listen for:

- `ETA_ListManager_ChangeNotification_Lists` when lists changed
- `ETA_ListManager_ChangeNotification_ListItems` when items changed

The userInfo dictionary supplied with both notification types is of the same form - three lists of objects under the keys `ETA_ListManager_ChangeNotificationInfo_AddedKey`, `ETA_ListManager_ChangeNotificationInfo_RemovedKey` and `ETA_ListManager_ChangeNotificationInfo_ModifiedKey`. 

The `ETA_ListManager_ChangeNotificationInfo_ModifiedKey` notification will be called for shopping lists whenever anything changes with any of the items contained within that list.

