//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import XCTest
@testable import ShopGunSDK

class EventShipper_v2Tests: XCTestCase {

    var shipper: EventsShipper_v2!
    
    override func setUp() {
        shipper = EventsShipper_v2(baseURL: URL(string: "https://events.service-staging.shopgun.com")!, dryRun: false)
    }

//    func testExample() {
//
//        let events = [Event.dummy().addingAppIdentifier("AAAhWQ=="), Event.dummy().addingAppIdentifier("AAAhWQ==")]
//
//        let expectCallback = expectation(description: "Shipping News")
//
//        shipper.ship(events: events.compactMap(ShippableEvent.init(event:))) { (results) in
//            print(results)
//            expectCallback.fulfill()
//        }
//
//        waitForExpectations(timeout: 90) { (error) in
//            if let error = error {
//                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
//            }
//        }
//    }

}
