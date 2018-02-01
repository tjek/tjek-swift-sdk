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
    
    func publicationOpenedEvent(publication: PagedPublicationView.PublicationModel)
    
    func publicationPageLoadedEvent(pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageHotspotsClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageDoubleClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageLongPressedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    
    func publicationSpreadAppearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
    func publicationSpreadDisappearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
    func publicationSpreadZoomedIn(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
    func publicationSpreadZoomedOut(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
}

extension PagedPublicationView {
    class EventsHandler: PagedPublicationViewEventHandler {
        func publicationOpenedEvent(publication: PagedPublicationView.PublicationModel) {
            print("Publication Opened")
        }
        
        func publicationPageLoadedEvent(pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
            print("Publication Page Loaded", pageIndex)
        }
        
        func publicationPageClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
//            print("Publication Page Clicked", pageIndex)
        }
        
        func publicationPageHotspotsClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
//            print("Publication Page hotspots Clicked", pageIndex)
        }
        
        func publicationPageDoubleClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
//            print("Publication Page double Clicked", pageIndex)
        }
        
        func publicationPageLongPressedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
//            print("Publication Page long pressed", pageIndex)

        }
        
        func publicationSpreadAppearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
            print("Publication spread appeared \(pageIndexes)")

        }
        
        func publicationSpreadDisappearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
//            print("Publication spread disappeared", pageIndexes)
        }
        
        func publicationSpreadZoomedIn(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
//            print("Publication spread zoomedin", pageIndexes)
        }
        
        func publicationSpreadZoomedOut(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
//            print("Publication spread zoomedout", pageIndexes)
        }
    }
}

extension PagedPublicationView {
    
    class LifecycleEventTracker {
        
        let eventHandler: PagedPublicationViewEventHandler
        let publicationModel: PublicationModel
        
        fileprivate var hasAppeared: Bool = false
        
        init(publicationModel: PagedPublicationView.PublicationModel, eventHandler: PagedPublicationViewEventHandler) {
            self.eventHandler = eventHandler
            self.publicationModel = publicationModel
        }
        deinit {
            didDisappear()
        }
        
        // trigger an opened event
        func opened() {
            eventHandler.publicationOpenedEvent(publication: publicationModel)
        }
        
        func didAppear() {
            guard hasAppeared == false else { return }
            
            spreadLifecycleTracker?.didAppear()
            
            hasAppeared = true
        }
        
        func didDisappear() {
            guard hasAppeared == true else { return }
            
            spreadLifecycleTracker?.didDisappear()
            
            hasAppeared = false
        }
        
        // MARK: Child event handlers
        
        func newSpreadLifecycleTracker(for pageIndexes: IndexSet) {
            spreadLifecycleTracker = SpreadLifecycleEventTracker(pageIndexes: pageIndexes, publicationModel: self.publicationModel, eventHandler: self.eventHandler)
        }
        func clearSpreadLifecycleTracker() {
            spreadLifecycleTracker = nil
        }
        
        private(set) var spreadLifecycleTracker: SpreadLifecycleEventTracker? {
            didSet {
                if self.hasAppeared {
                    spreadLifecycleTracker?.didAppear()
                }
            }
        }
    }

    class SpreadLifecycleEventTracker {

        let eventHandler: PagedPublicationViewEventHandler
        let publicationModel: PublicationModel
        let pageIndexes: IndexSet

        init(pageIndexes: IndexSet, publicationModel: PagedPublicationView.PublicationModel, eventHandler: PagedPublicationViewEventHandler) {
            self.eventHandler = eventHandler
            self.publicationModel = publicationModel
            self.pageIndexes = pageIndexes
        }

        deinit {
            didDisappear()
        }

        fileprivate(set) var loadedPageIndexes: IndexSet = IndexSet()
        fileprivate(set) var isZoomedIn: Bool = false

        fileprivate var hasAppeared: Bool = false

        // only parent can call these methods - everyone else can just set this class on the parent lifecycle
        fileprivate func didAppear() {
            guard hasAppeared == false else { return }

            // first spread appears
            eventHandler.publicationSpreadAppearedEvent(pageIndexes: pageIndexes, publication: publicationModel)

            // then pages appear (and load if already loaded)
            for pageIndex in pageIndexes {
                if loadedPageIndexes.contains(pageIndex) {
                    eventHandler.publicationPageLoadedEvent(pageIndex: pageIndex, publication: publicationModel)
                }
            }

            // finally zoom in (if already zoomed in)
            if isZoomedIn {
                eventHandler.publicationSpreadZoomedIn(pageIndexes: pageIndexes, publication: publicationModel)
            }

            hasAppeared = true
        }

        fileprivate func didDisappear() {
            guard hasAppeared == true else { return }

            // first zoom out (if zoomed in)
            if isZoomedIn {
                eventHandler.publicationSpreadZoomedOut(pageIndexes: pageIndexes, publication: publicationModel)
            }

            // disappear the spread
            eventHandler.publicationSpreadDisappearedEvent(pageIndexes: pageIndexes, publication: publicationModel)

            hasAppeared = false
        }

        /// Mark the page index as loaded, and trigger a didLoad event if the page has appeared
        public func pageLoaded(pageIndex: Int) {
            guard pageIndexes.contains(pageIndex) else {
                return
            }

            loadedPageIndexes.insert(pageIndex)

            guard hasAppeared == true else {
                return
            }

            eventHandler.publicationPageLoadedEvent(pageIndex: pageIndex, publication: publicationModel)
        }

        public func pageTapped(pageIndex: Int, location: CGPoint, hittingHotspots: Bool) {
            guard pageIndexes.contains(pageIndex) else {
                return
            }

            guard hasAppeared == true else {
                return
            }

            eventHandler.publicationPageClickedEvent(location: location, pageIndex: pageIndex, publication: publicationModel)

            if hittingHotspots {
                eventHandler.publicationPageHotspotsClickedEvent(location: location, pageIndex: pageIndex, publication: publicationModel)
            }
        }

        public func pageDoubleTapped(pageIndex: Int, location: CGPoint) {
            guard pageIndexes.contains(pageIndex) else {
                return
            }

            guard hasAppeared == true else {
                return
            }

            eventHandler.publicationPageDoubleClickedEvent(location: location, pageIndex: pageIndex, publication: publicationModel)
        }

        public func pageLongPressed(pageIndex: Int, location: CGPoint) {
            guard pageIndexes.contains(pageIndex) else {
                return
            }

            guard hasAppeared == true else {
                return
            }

            eventHandler.publicationPageLongPressedEvent(location: location, pageIndex: pageIndex, publication: publicationModel)
        }

        public func didZoomIn() {
            // check we are not already zoomed in - othewise noop
            guard isZoomedIn == false else {
                return
            }

            isZoomedIn = true

            // dont trigger any events if we are not visible
            guard hasAppeared == true else {
                return
            }

            eventHandler.publicationSpreadZoomedIn(pageIndexes: pageIndexes, publication: publicationModel)
        }

        public func didZoomOut() {
            // check we are zoomed in - othewise noop
            guard isZoomedIn == true else {
                return
            }

            isZoomedIn = false

            // dont trigger any events if we are not visible
            guard hasAppeared == true else {
                return
            }

            eventHandler.publicationSpreadZoomedOut(pageIndexes: pageIndexes, publication: publicationModel)
        }
    }
}
