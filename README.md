# ETA
> \#import "ETA.h"

The `ETA` class is the main interface into the eTilbudsAvis SDK. It handles all the boring session management stuff, freeing you to simply call any of the API methods you wish.



# ETA_APIEndpoints
> \#import "ETA_APIEndpoints.h"


# ETA_ShoppingListManager
> \#import "ETA_ShoppingListManager.h"

The world of Shopping Lists is a lot more complex than any of the other parts of the new API, so we provide the `ETA_ShoppingListManager` through which all ShoppingList related communication should happen.

You create an instance of the manager with `+managerWithETA:`, passing in the `ETA` SDK object. You will only really need to create one, and although multiple instances _should_ work, it is untested (they would be using the same local database).

## Polling & Syncing

The main job of the manager is keeping a local store of `ETA_ShoppingList` and `ETA_ShoppingListItem` objects in sync with the the server. It does this by polling the server at a regular interval for changes to the lists and items. 

You can change the rate of this polling using the `pollRate` property (for example, perhaps you want to slow down or stop the polling when not looking at the shopping lists).

### Attached User
One major thing to note is that the behaviour of the `ETA_ShoppingListManager` is closely tied to the `ETA` object's `attachedUser` property (so if you pass nil when creating the manager you will only work locally). 

If there is no attached user, the manager will not be able to sync changes to the server, and so will not poll, and all changes you make will be saved to a 'userless' local store. As soon as a user is attached (by logging in) the changes that are now made will be saved to a 'user' local store, and also sent to the server. 

It is your responsibility to merge any changes from the 'userless' local store to server (perhaps asking the user which of their online lists they want to move the userless items to). To help with this migration there is a flag on the manager called `ignoreAttachedUser`. When set to YES the `ETA`'s user will not be taken into account, polling will be ignored, and any queries or actions will be applied to the 'userless' local store, and not passed to the server.

### Failure handling
The server is always considered the truth when it comes to syncing. However, if there are changes on the client side we will not poll and ask the server for it's state until all those changes are successfully sent. 

Great effort has been made to make sure that if something goes wrong while sending a change request to the server it will not be lost. It will retry a number of times, and if that fails it will enter a slow retry cycle (this would happen if the app has gone offline). If the app shuts down before the changes are sent, when the manager starts again and logs in with the same user we will retry sending the changes before we start polling again. 

This may cause a problem if the user logs in with a different userID before the local changes for the previous user are sent. This is because there is only one local store for all users, and this is cleared and replaced with the server state when a different user logs in. Logging off and on with the same user will not be a problem.


## Methods


### Getters
All the `get…` queries will give you the results from the local store, as up to date with the server as the last poll.


### Setters






# ETA_PageFlip
> \#import "ETA_PageFlip.h"

`ETA_PageFlip` is a UIView that contains all the functionality you need to show an interactive catalog.

Simply add an instance of the `ETA_PageFlip` to a view, and call `-startLoadWithETA:`, passing in the `ETA` SDK object. Now, calling `-showCatalogView:` with a catalog's UUID will update the PageFlip view to show an interactive catalog. You can optionally pass in a dictionary with parameters for how to display the catalog. These parameters are:

- `page`: The desired page to start on (`NSUInteger` default=1)
- `hotspots`: Whether to send events when a hotspot is pressed (`BOOL` default=YES)
- `hotspotOverlay`: Whether to show an overlay when hovering over a hotspot - doesnt make sense for iOS (`BOOL` default=NO)
- `canClose`: Whether the catalog view can close or not (`BOOL` default=NO)
- `headless`: Whether the header should be hidden or shown (`BOOL` default=YES)
- `outOfBounds`: Whether to show a dialog when past the last page (`BOOL` default=NO)
- `whiteLabel`: Whether to show ETA branding (`BOOL` default=YES)

For example, to open a PageFlip to page 5 of a catalog, send the following message:
`[self.pageFlip showCatalog:@"abcdef123" parameters:@{
@"page":@5 }];`

Additionally, the `-toggleCatalogViewThumbnails` will show an overlay of all the pages to allow the user to quickly pick the page they wish to go to.

#### PageFlip events
If you want to know what the user is doing within the PageFlip view, set your ViewController as the PageFlip's `etaDelegate`, and implement as many of the (optional) `ETAPageFlipDelegate` methods as you need. 

A special delegate method is `-etaPageFlip:triggeredEventWithClass:type:dataDictionary:`. This will be triggered for **all** catalog events _unless_ you implement the corresponding delegate method. For example, if you implement the `-etaPageFlip:catalogViewSingleTapEvent:` delegate method you will not receive the `…triggeredEventWithClass:…` delegate call for that event.






*2013-07-24*