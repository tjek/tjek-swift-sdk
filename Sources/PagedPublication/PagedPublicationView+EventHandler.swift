//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

/// All the possible events that the paged publication can trigger
public protocol PagedPublicationViewEventHandler {
    func didOpenPublication(_ publicationId: PagedPublicationView.PublicationModel.Identifier)
    func didCloseLoadedPublicationPage(_ publicationId: PagedPublicationView.PublicationModel.Identifier, pageIndex: Int)
}

extension PagedPublicationView {
    
    /// The class that handles events via the shared EventsTracker.
    class EventsHandler: PagedPublicationViewEventHandler {
        
        private var eventsTracker: EventsTracker? {
            return EventsTracker.isConfigured ? EventsTracker.shared : nil
        }
        
        public func didOpenPublication(_ publicationId: PagedPublicationView.PublicationModel.Identifier) {
            eventsTracker?.trackEvent(
                .pagedPublicationOpened(publicationId)
            )
        }
        
        public func didCloseLoadedPublicationPage(_ publicationId: PagedPublicationView.PublicationModel.Identifier, pageIndex: Int) {
            
            eventsTracker?.trackEvent(
                .pagedPublicationPageOpened(publicationId,
                                            pageNumber: pageIndex + 1)
            )
        }
    }
}

extension PagedPublicationView {

    class LifecycleEventTracker {

        let eventHandler: PagedPublicationViewEventHandler
        
        let publicationId: PublicationModel.Identifier
        var currentSpreadPageIndexes: IndexSet = IndexSet()
        var loadedSpreadPageIndexes: IndexSet = IndexSet()

        fileprivate var hasAppeared: Bool = false

        init(publicationId: PublicationModel.Identifier, eventHandler: PagedPublicationViewEventHandler) {
            self.eventHandler = eventHandler
            self.publicationId = publicationId
        }
        deinit {
            didDisappear()
        }

        // trigger an opened event
        func opened() {
           eventHandler.didOpenPublication(publicationId)
        }

        func didAppear() {
            guard hasAppeared == false else { return }

            hasAppeared = true
        }

        func didDisappear() {
            guard hasAppeared == true else { return }
            Logger.log("DidDisappear", level: .debug, source: .EventsTracker)
            // trigger the disappear events without clearing the indexes
            self.loadedSpreadPageIndexes.forEach {
                eventHandler.didCloseLoadedPublicationPage(publicationId, pageIndex: $0)
            }
            
            hasAppeared = false
        }

        // MARK: Child event handlers

        func pageDidLoad(pageIndex: Int) {
            guard currentSpreadPageIndexes.contains(pageIndex) else {
                 return
            }
            
            Logger.log("Page Did Load (\(pageIndex))", level: .debug, source: .EventsTracker)
            loadedSpreadPageIndexes.insert(pageIndex)
        }
        
        func spreadDidAppear(pageIndexes: IndexSet, loadedIndexes: IndexSet) {
            Logger.log("Spread Did Appear (\(pageIndexes) loaded: \(loadedIndexes))", level: .debug, source: .EventsTracker)
            
            // Figure out which loaded pageIndexes have been closed
            let closedLoadedPageIndexes = loadedSpreadPageIndexes.subtracting(pageIndexes)
            closedLoadedPageIndexes.forEach {
                eventHandler.didCloseLoadedPublicationPage(publicationId, pageIndex: $0)
            }
            
            self.currentSpreadPageIndexes = pageIndexes
            self.loadedSpreadPageIndexes = loadedIndexes
            
        }
        
        func spreadDidDisappear() {
            Logger.log("Spread Did Disappear (\(self.currentSpreadPageIndexes) loaded: \(self.loadedSpreadPageIndexes))", level: .debug, source: .EventsTracker)
            
            self.loadedSpreadPageIndexes.forEach {
                eventHandler.didCloseLoadedPublicationPage(publicationId, pageIndex: $0)
            }
            self.loadedSpreadPageIndexes = IndexSet()
            self.currentSpreadPageIndexes = IndexSet()
        }
    }
}
