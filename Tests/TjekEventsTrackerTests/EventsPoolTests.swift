///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import XCTest
@testable import TjekEventsTracker

class EventsPoolTests: XCTestCase {

    func testDispatch() {
        
        var expectShipping = expectation(description: "DispatchLimit ships events")
        
        let cache = EventsCache<ShippableEvent>(fileName: "foo.plist", directory: nil)
        
        var shippedEvents: [ShippableEvent] = []
        
        let shipper: EventsPool.EventShippingHandler = { (events: [ShippableEvent], completion) -> Void in
            
            shippedEvents = events
            
            completion(events.reduce(into: [:], {
                $0[$1.cacheId] = .success
            }))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                expectShipping.fulfill()
            })
        }
        
        let pool = EventsPool(dispatchInterval: 3,
                              dispatchLimit: 2,
                              shippingHandler: shipper,
                              cache: cache)
        
        pool.push(event: ShippableEvent(event: Event(id: "a", type: 0))!)
        pool.push(event: ShippableEvent(event: Event(id: "b", type: 0))!)
        pool.push(event: ShippableEvent(event: Event(id: "c", type: 0))!)
        wait(for: [expectShipping], timeout: 2)
        
        // Make sure that last object remains, and the first 2 are shipped
        XCTAssertEqual(cache.objectCount, 1)
        XCTAssertEqual(shippedEvents.map({ $0.cacheId }), ["a", "b"])
        
        expectShipping = expectation(description: "DispatchInterval ships events")
        
        // make sure the last event is shipped after the dispatch interval
        wait(for: [expectShipping], timeout: 5)
        XCTAssertEqual(cache.objectCount, 0)
        XCTAssertEqual(shippedEvents.map({ $0.cacheId }), ["c"])
    }
}
