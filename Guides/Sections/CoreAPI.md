The CoreAPI simplifies auth & communication with the ShopGun REST API.

> TODO:
>
>  - Request construction
>  - Calling Requests
>  - Cancelling requests
> 

The `CoreAPI` component provides typesafe tools for working with the ShopGun API, and removes the need to consider any of the session and auth-related complexity when making requests.

> **Note:** You must provide a `key` and `secret` when configuring the ShopGunSDK, otherwise calls to the CoreAPI will trigger a fatalError. 
> 
> These can be requested by signing into the [ShopGun Developers](https://shopgun.com/developers) page.

The interface for making requests is very flexible, but a large number of pre-built requests have been included. For example:

```swift
// make a request object that will ask for a specific PagedPublication object
let req = CoreAPI.getPagedPublication(withId: …)

// Perform the request. The completion handler is passed a Result object containing the requested PagedPublication, or an error.
CoreAPI.shared.request(req) { (result) in
	switch result {
	case .success(let pagedPublication):
	   print("👍 '\(pagedPublication.id.rawValue)' loaded")
	case .error(let err):
	   print("😭 Load Failed: '\(err.localizedDescription)'")
}

```
