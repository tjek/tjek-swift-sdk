# Change Log

## v5.1

> Minimum supported deployment target is now iOS 13 (previously iOS 12)

This release adds support for the async/await model of concurrency. It changes both the APIClient and TjekAPI objects to become actors.

- `TjekAPI.send(…)` is now an `async` function (though it is still possible to use the callback and Future versions of this function).
- `APIRequest` now no longer has a version tag. If you need to define a new APIRequest, you define the endpoint version by picking the correct `.v2()` or `.v4()` static initializers function.
- `TjekAPI.initialize` will now fatalError if called more than once. In order to re-initialize the API, you must call `await TjekAPI.shared.update(config:)`


## v5.0.3

- Adds opening hours to the `Store_v2` model
- Remove the need for API secret

## v5.0.2

- Fix issue with `getPublications` request where storeIds filter was not being applied properly

## v5.0.1

- Adds a search request & a specific model for offer hotspots 

## v5.0

> This release is not backwards-compatible with the previous versions.

This release sees a major overhaul of the structure of the SDK, to modularize it so that the separate components can be loaded independently. It also adds full support for Swift Package Manager.

### v4 -> v5 migration

A number of types and functions have been renamed, while others have stayed the same.

- `ShopGunSDK` is now `TjekSDK`:
	- Use `import TjekSDK` instead of `import ShopGunSDK`.
	- `ShopGunSDK-Config.plist` is now `TjekSDK-Config.plist`, and the structure of the file has been flattened (see the Examples projects).
	- Previously you had to call `PagedPublicationView.configure()` to initialize the SDK. Now you need to call `TjekSDK.initialize()`.

- `CoreAPI` has been replaced with `TjekAPI`:
	- To send a request you now use `send(_:)` on a `TjekAPI` instance, instead of `request(_:)` on a `CoreAPI` instance.
	- All the model objects from `CoreAPI` have been renamed to `<ModelObject>_v2`, and some of their properties have been adjusted/unified slightly.
	- We have added a number of `*_v4` model objects too, which are accessible view v4 api requests.
	- `ImageURLSet` has been replaced with `Set<ImageURL>` for more flexibility.

- Both `IncitoLoaderViewController` and `PagedPublicationView` are now included in the same library: `TjekPublicationViewer`. This is imported by default when importing `TjekSDK`.
	- `IncitoLoaderViewController` is unchanged (apart from now using TjekAPI instead of the old GraphAPI).
	- `PagedPublicationView` is unchanged (apart from now using TjekAPI under the hood).

**Carthage** support has been removed. 
> Due to the addition of SPM support, and the amount of work needed to continue supporting this dependency manager, along with a number of technical hurdles, we have decided to drop support. We recommend you use the Swift Package Manager instead. If anyone wishes to add support, we will gladly accept a PR.      

## v4.2
**Swift 5.0.1 now required**

- Replaces IncitoViewController renderer with a web-view based one.
- Add Carthage demo

## v4.1
**Swift 4.2 now required**

- Add support for `IncitoLoaderViewController`.
- Adds Finnish localizations.
- New `EventsTracker`, with a privacy-first format.
- Added new `getPagedPublication(forDealers:...)` CoreAPI request.
- Add dealerIds filter to `getOffers(matchingSearch:...)` CoreAPI request.
- Add optional location filter to `getSuggestedPublications` CoreAPI request.
- Add Carthage support.
- Add `isAvailableInAllStores` property to PagedPublication.
- Allow using private keychains with custom names.
- Fix issue related to request parameter url-encoding.
- Fix loading too-large page images.
- Removes progress bar from PagedPublication view
- Remove CryptoSwift dependency.
- Update `Kingfisher ~> 4.10.0` 
- Update `Valet ~> 3.1.6`

## v4.0.2
- Fix issue when building for Release (`GenericIdentifier` was not decoding correctly)

## v4.0.1
**Swift 4.1 now required**

- Migrate SDK code from Swift 4.0 to 4.1.
- Update 3rd party dependencies:
	- `Verso` 1.0.1 -> 1.0.2
	- `Kingfisher` 4.6.4 -> 4.7.0
	- `CryptoSwift` 0.8.3 -> 0.9.0
- Changes to the CoreAPI.Dealer model object.

## v4.0.0
This is a complete re-write of the SDK in Swift 4.0.


## v3.1.0

##### Now requires iOS 7 and up
* Update to *AFNetworking ~> 3.0.0*


## v3.0.0
* Sends system locale (eg "en_GB") with every request
* Update to *Mantle ~> 1.5.6*
* Update to *FMDB ~> 2.5* 

##### Breaking Changes
* Use new error system. See `SGN_APIErrors.h` for domains, codes, and utility methods (all error methods on `ETA` class have been removed, and error domain has been renamed).

## v2.3.1
* Update to *AFNetworking ~> 2.5.1*
* Remove deprecated `urlName` & `logoBackgroundColor` properties from `ETA_Dealer` and `ETA_Branding` model objects.

## v2.3.0
* SDK split into multiple subpecs, for when you only need some of the components
* New Native Catalog Reader with new example project. The old web-based CatalogView is deprecated.
* Update to *CocoaLumberjack ~> 1.9.0*
* Request timeout reduced to 20 secs (was 60 secs previously)
* Better handling of errors when syncing shopping lists

## v2.2.3
* Documentation update
* Fixed CatalogView delegate removal issue

## v2.2.2
* Removed `verbose` properties
* Replace logging system with CocoaLumberjack, and update examples
* Update to *AFNetworking ~> 2.2.4*
* Update to *Mantle ~> 1.4.1*
* Added Dealer model object
* Added ClientID to sessions

## v2.2.1
* Performs CatalogView requests in the background
* Minor bug fixes
* Better Examples project structure

## v2.2.0
* **Now requires >= iOS 6.0** (Update to AFNetworking ~> 2.1)
* ETA_ListManager `- createListItem:offerID:...` now requires an item count.
* Number of bug fixes


## v2.1.1
* Session migration bugfix
* Other minor bug fixes

## v2.1.0
* `ETA` initialization now requires an appVersion
* Added methods for attaching a facebook user to `ETA`.
* Added an observable 'connected' property to `ETA`.
* Added pause and gotoPage methods to `ETA_CatalogView`.
* `ETA_ListManager` has been renamed, and there has been major internal and external refactoring.

## v2.0.0
* Everything is new!

