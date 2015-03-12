# eTilbudsavis iOS SDK - Change Log

## v2.3.1
* Update to *AFNetworking ~> 2.5.1*

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

