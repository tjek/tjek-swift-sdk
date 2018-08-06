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
@available(*, deprecated)
public protocol PagedPublicationViewEventHandler {
    
    func publicationOpenedEvent(publication: PagedPublicationView.PublicationModel)
    
    func publicationPageLoadedEvent(pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageHotspotsClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageDoubleClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    func publicationPageLongPressedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel)
    
    func publicationSpreadAppearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
    func publicationSpreadDisappearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
    func publicationSpreadZoomedInEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
    func publicationSpreadZoomedOutEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel)
}

extension PagedPublicationView {
    class EventsHandler: PagedPublicationViewEventHandler {
        
        @available(*, deprecated)
        enum PublicationEvents {
            typealias PublicationModel = PagedPublicationView.PublicationModel
            
            case opened(PublicationModel)
            
            case pageLoaded(pageIndex: Int, publication: PublicationModel)
            case pageClicked(location: CGPoint, pageIndex: Int, publication: PublicationModel)
            case pageHotspotsClicked(location: CGPoint, pageIndex: Int, publication: PublicationModel)
            case pageDoubleClicked(location: CGPoint, pageIndex: Int, publication: PublicationModel)
            case pageLongPressed(location: CGPoint, pageIndex: Int, publication: PublicationModel)
            
            case spreadAppeared(pageIndexes: IndexSet, publication: PublicationModel)
            case spreadDisappeared(pageIndexes: IndexSet, publication: PublicationModel)
            case spreadZoomedIn(pageIndexes: IndexSet, publication: PublicationModel)
            case spreadZoomedOut(pageIndexes: IndexSet, publication: PublicationModel)

            // MARK: -
            
            var type: String {
                switch self {
                case .opened:
                    return "paged-publication-opened"
                case .pageLoaded:
                    return "paged-publication-page-loaded"
                case .pageClicked:
                    return "paged-publication-page-clicked"
                case .pageHotspotsClicked:
                    return "paged-publication-page-hotspots-clicked"
                case .pageDoubleClicked:
                    return "paged-publication-page-double-clicked"
                case .pageLongPressed:
                    return "paged-publication-page-long-pressed"
                case .spreadAppeared:
                    return "paged-publication-page-spread-appeared"
                case .spreadDisappeared:
                    return "paged-publication-page-spread-disappeared"
                case .spreadZoomedIn:
                    return "paged-publication-page-spread-zoomed-in"
                case .spreadZoomedOut:
                    return "paged-publication-page-spread-zoomed-out"
                }
            }
            
            var properties: [String: AnyObject] {
                switch self {
                case let .opened(publication):
                    return ["pagedPublication": self.publicationProperties(publication) as AnyObject]
                    
                case let .pageLoaded(pageIndex, publication):
                    return ["pagedPublication": self.publicationProperties(publication) as AnyObject,
                            "pagedPublicationPage": self.pageProperties(location: nil, pageIndex: pageIndex) as AnyObject]
                    
                case let .pageClicked(location, pageIndex, publication),
                     let .pageHotspotsClicked(location, pageIndex, publication),
                     let .pageDoubleClicked(location, pageIndex, publication),
                     let .pageLongPressed(location, pageIndex, publication):
                    return ["pagedPublication": self.publicationProperties(publication) as AnyObject,
                            "pagedPublicationPage": self.pageProperties(location: location, pageIndex: pageIndex) as AnyObject]
                    
                case let .spreadAppeared(pageIndexes, publication),
                     let .spreadDisappeared(pageIndexes, publication),
                     let .spreadZoomedIn(pageIndexes, publication),
                     let .spreadZoomedOut(pageIndexes, publication):
                    return ["pagedPublication": self.publicationProperties(publication) as AnyObject,
                            "pagedPublicationPageSpread": self.spreadProperties(pageIndexes: pageIndexes) as AnyObject]

                }
            }
            
            func track() {
                guard EventsTracker.isConfigured else { return }

//                EventsTracker.shared.trackEvent(self.type, properties: self.properties)
            }
            
            private func publicationProperties(_ publication: PublicationModel) -> [String: AnyObject] {
                return [:]
//                return ["id": EventsTracker.IdField.legacy(publication.id.rawValue).jsonArray() as AnyObject,
//                        "ownedBy": EventsTracker.IdField.legacy(publication.dealerId.rawValue).jsonArray() as AnyObject]
            }

            private func pageProperties(location: CGPoint?, pageIndex: Int) -> [String: AnyObject] {
                
                var pageProperties = ["pageNumber": (pageIndex + 1) as AnyObject]
                if let loc = location {
                    pageProperties["x"] = loc.x as AnyObject
                    pageProperties["y"] = loc.y as AnyObject
                }
                return pageProperties
            }
            
            private func spreadProperties(pageIndexes: IndexSet) -> [String: AnyObject] {
                return ["pageNumbers": pageIndexes.map({ $0 + 1 }) as AnyObject]
            }
        }
        
        // MARK: -
        
        func publicationOpenedEvent(publication: PagedPublicationView.PublicationModel) {
            guard EventsTracker.isConfigured else { return }

            EventsTracker.shared.trackEvent(.pagedPublicationOpened(publication.id))
        }
        
        func publicationPageLoadedEvent(pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
            guard EventsTracker.isConfigured else { return }
            
            EventsTracker.shared.trackEvent(.pagedPublicationPageOpened(publication.id, pageNumber: pageIndex + 1))
        }
        
        func publicationPageClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.pageClicked(location: location, pageIndex: pageIndex, publication: publication).track()
        }
        
        func publicationPageHotspotsClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.pageHotspotsClicked(location: location, pageIndex: pageIndex, publication: publication).track()
        }
        
        func publicationPageDoubleClickedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.pageDoubleClicked(location: location, pageIndex: pageIndex, publication: publication).track()
        }
        
        func publicationPageLongPressedEvent(location: CGPoint, pageIndex: Int, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.pageLongPressed(location: location, pageIndex: pageIndex, publication: publication).track()
        }
        
        func publicationSpreadAppearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.spreadAppeared(pageIndexes: pageIndexes, publication: publication).track()
        }
        
        func publicationSpreadDisappearedEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.spreadDisappeared(pageIndexes: pageIndexes, publication: publication).track()
        }
        
        func publicationSpreadZoomedInEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.spreadZoomedIn(pageIndexes: pageIndexes, publication: publication).track()
        }
        
        func publicationSpreadZoomedOutEvent(pageIndexes: IndexSet, publication: PagedPublicationView.PublicationModel) {
            PublicationEvents.spreadZoomedOut(pageIndexes: pageIndexes, publication: publication).track()
        }
    }
}

extension PagedPublicationView {
    
    @available(*, deprecated)
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
                eventHandler.publicationSpreadZoomedInEvent(pageIndexes: pageIndexes, publication: publicationModel)
            }

            hasAppeared = true
        }

        fileprivate func didDisappear() {
            guard hasAppeared == true else { return }

            // first zoom out (if zoomed in)
            if isZoomedIn {
                eventHandler.publicationSpreadZoomedOutEvent(pageIndexes: pageIndexes, publication: publicationModel)
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

            eventHandler.publicationSpreadZoomedInEvent(pageIndexes: pageIndexes, publication: publicationModel)
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

            eventHandler.publicationSpreadZoomedOutEvent(pageIndexes: pageIndexes, publication: publicationModel)
        }
    }
}
