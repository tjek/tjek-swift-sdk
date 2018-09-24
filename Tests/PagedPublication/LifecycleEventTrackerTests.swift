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

class PagedPublicationLifecycleEventTrackerTests: XCTestCase {
    
    func testDidOpen() {
        let eventHandler = MockEventHandler()
        
        let tracker = PagedPublicationView.LifecycleEventTracker(publicationId: "abc", eventHandler: eventHandler)
        
        // Wait for the open event
        let expectOpenPub = expectation(description: "Did Open")
        eventHandler.didOpenPub = { pubId in
            XCTAssert(pubId.rawValue == "abc")
            
            expectOpenPub.fulfill()
        }
        tracker.opened()
        wait(for: [expectOpenPub], timeout: 1)
    }
    
    func testCloseLoadedPages() {
        let eventHandler = MockEventHandler()
        
        let tracker = PagedPublicationView.LifecycleEventTracker(publicationId: "abc", eventHandler: eventHandler)
        
        // Wait for the open event
        let expectPage2 = expectation(description: "Did Close Page 2")
        let expectPage3 = expectation(description: "Did Close Page 3")
        eventHandler.didCloseLoadedPubPage = { pubId, pageIndex in
            XCTAssert(pubId.rawValue == "abc")
            XCTAssert([2, 3].contains(pageIndex))
            if pageIndex == 2 {
                expectPage2.fulfill()
            } else if pageIndex == 3 {
                expectPage3.fulfill()
            }
        }
        
        tracker.pageDidLoad(pageIndex: 1)
        tracker.spreadDidAppear(pageIndexes: IndexSet([1, 2, 3]), loadedIndexes: IndexSet([2]))
        tracker.pageDidLoad(pageIndex: 3)
        tracker.pageDidLoad(pageIndex: 4)
        tracker.spreadDidDisappear()
        wait(for: [expectPage2, expectPage3], timeout: 1)
    }
    
    func testClosingWhenOpeningNewSpreads() {
        let eventHandler = MockEventHandler()
        
        let tracker = PagedPublicationView.LifecycleEventTracker(publicationId: "abc", eventHandler: eventHandler)
        
        // Wait for the open event
        let expectPage1 = expectation(description: "Did Close Only Page 1")
        expectPage1.isInverted = true
        eventHandler.didCloseLoadedPubPage = { pubId, pageIndex in
            XCTAssert([1].contains(pageIndex))
            if pageIndex != 1 {
                expectPage1.fulfill()
            }
        }
        
        tracker.spreadDidAppear(pageIndexes: IndexSet([1, 2]), loadedIndexes: IndexSet([1, 2]))
        tracker.spreadDidAppear(pageIndexes: IndexSet([2, 3]), loadedIndexes: IndexSet([2, 3]))
        
        wait(for: [expectPage1], timeout: 1)
    }
    
    func testDidDisappear() {
        let eventHandler = MockEventHandler()
        
        let tracker = PagedPublicationView.LifecycleEventTracker(publicationId: "abc", eventHandler: eventHandler)
        
        // Wait for the open event
        let expectNoPage1 = expectation(description: "Shouldnt Close Page 1")
        expectNoPage1.isInverted = true
        let expectPage1 = expectation(description: "Should Close Page 1")
                
        tracker.spreadDidAppear(pageIndexes: IndexSet([1]), loadedIndexes: IndexSet([1]))
        
        eventHandler.didCloseLoadedPubPage = { pubId, pageIndex in
            XCTAssert(pubId.rawValue == "abc")
            XCTAssert(pageIndex == 1)
            expectNoPage1.fulfill()
        }
        
        // should not trigger events, if didAppear not called first
        tracker.didDisappear()
        
        eventHandler.didCloseLoadedPubPage = { pubId, pageIndex in
            XCTAssert(pubId.rawValue == "abc")
            XCTAssert(pageIndex == 1)
            expectPage1.fulfill()
        }
        
        tracker.didAppear()
        // should now trigger events
        tracker.didDisappear()

        wait(for: [expectNoPage1, expectPage1], timeout: 1)
    }
}

fileprivate class MockEventHandler: PagedPublicationViewEventHandler {
    
    var didOpenPub: ((PagedPublicationView.PublicationModel.Identifier) -> Void)?
    
    var didCloseLoadedPubPage: ((PagedPublicationView.PublicationModel.Identifier, Int) -> Void)?
    
    func didOpenPublication(_ publicationId: PagedPublicationView.PublicationModel.Identifier) {
        didOpenPub?(publicationId)
    }
    func didCloseLoadedPublicationPage(_ publicationId: PagedPublicationView.PublicationModel.Identifier, pageIndex: Int) {
        didCloseLoadedPubPage?(publicationId, pageIndex)
    }
}
