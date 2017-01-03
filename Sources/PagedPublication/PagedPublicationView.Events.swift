//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

// MARK: - Event Handling

class PagedPublicationLifecycleEventHandler {
    
    let publicationId:IdField
    let ownerId:IdField
    
    init(publicationId:IdField, ownerId:IdField) {
        self.publicationId = publicationId
        self.ownerId = ownerId
    }
    
    deinit {
        didDisappear()
    }
    
    // trigger an opened event
    func opened() {
        Event.publicationOpened(publicationId:publicationId, ownedById: ownerId).track()
    }
    
    
    
    fileprivate var hasAppeared:Bool = false
    
    func didAppear() {
        guard hasAppeared == false else { return }
        
        Event.publicationAppeared(publicationId:publicationId, ownedById: ownerId).track()
        
        spreadEventHandler?.didAppear()
        
        hasAppeared = true
    }
    
    func didDisappear() {
        guard hasAppeared == true else { return }
        
        spreadEventHandler?.didDisappear()
        
        Event.publicationDisappeared(publicationId:publicationId, ownedById: ownerId).track()
        
        hasAppeared = false
    }
    
    
    
    // MARK: Child event handlers
    
    func newSpreadEventHandler(for pageIndexes:IndexSet) {
        spreadEventHandler = SpreadLifecycleEventHandler(pageIndexes:pageIndexes, publicationId:self.publicationId, ownerId:self.ownerId)
    }
    func clearSpreadEventHandler() {
        spreadEventHandler = nil
    }
    
    
    private(set) var spreadEventHandler:SpreadLifecycleEventHandler? {
        didSet {
            if self.hasAppeared {
                spreadEventHandler?.didAppear()
            }
        }
    }
}

class SpreadLifecycleEventHandler {
    
    let publicationId:IdField
    let ownerId:IdField
    let pageIndexes:IndexSet
    
    init(pageIndexes:IndexSet, publicationId:IdField, ownerId:IdField) {
        self.publicationId = publicationId
        self.ownerId = ownerId
        
        self.pageIndexes = pageIndexes
    }

    deinit {
        didDisappear()
    }
    
    fileprivate(set) var loadedPageIndexes:IndexSet = IndexSet()
    fileprivate(set) var isZoomedIn:Bool = false
    
    fileprivate var hasAppeared:Bool = false
    
    
    // only parent can call these methods - everyone else can just set this class on the parent lifecycle
    fileprivate func didAppear() {
        guard hasAppeared == false else { return }
        
        // first spread appears
        Event.publicationSpreadAppeared(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId).track()
        
        // then pages appear (and load if already loaded)
        for pageIndex in pageIndexes {
            Event.publicationPageAppeared(pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
            
            if loadedPageIndexes.contains(pageIndex) {
                Event.publicationPageLoaded(pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
            }
        }
        
        // finally zoom in (if already zoomed in)
        if isZoomedIn {
            Event.publicationSpreadZoomedIn(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId).track()
        }
        
        hasAppeared = true
    }
    
    fileprivate func didDisappear() {
        guard hasAppeared == true else { return }
        
        
        // first zoom out (if zoomed in)
        if isZoomedIn {
            Event.publicationSpreadZoomedOut(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId).track()
        }
        
        
        // disappear all the pages
        for pageIndex in pageIndexes.reversed() {
            Event.publicationPageDisappeared(pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
        }
        
        // disappear the spread
        Event.publicationSpreadDisappeared(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId).track()
        
        hasAppeared = false
    }
    
    
    
    /// Mark the page index as loaded, and trigger a didLoad event if the page has appeared
    public func pageLoaded(pageIndex:Int) {
        guard pageIndexes.contains(pageIndex) else {
            return
        }
        
        loadedPageIndexes.insert(pageIndex)
        
        guard hasAppeared == true else {
            return
        }
        
        Event.publicationPageLoaded(pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
    }
    
    
    public func pageTapped(pageIndex:Int, location:CGPoint, hittingHotspots:Bool) {
        guard pageIndexes.contains(pageIndex) else {
            return
        }
        
        guard hasAppeared == true else {
            return
        }
        
        Event.publicationPageClicked(location:location, pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
        
        if hittingHotspots {
            Event.publicationPageHotspotsClicked(location:location, pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
        }
    }
    
    public func pageDoubleTapped(pageIndex:Int, location:CGPoint) {
        guard pageIndexes.contains(pageIndex) else {
            return
        }
        
        guard hasAppeared == true else {
            return
        }
        
        Event.publicationPageDoubleClicked(location:location, pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
    }
    
    public func pageLongPressed(pageIndex:Int, location:CGPoint) {
        guard pageIndexes.contains(pageIndex) else {
            return
        }
        
        guard hasAppeared == true else {
            return
        }
        
        Event.publicationPageLongPressed(location:location, pageIndex: pageIndex, publicationId: publicationId, ownedById: ownerId).track()
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
        
        Event.publicationSpreadZoomedIn(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId).track()
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
        
        Event.publicationSpreadZoomedOut(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId).track()
    }
}






extension Event {
    
    // MARK: Publication Events

    private static func _publicationEvent(type:String, publicationId:IdField, ownedById:IdField) -> Event {
        
        let pubProperties = ["id": publicationId.jsonArray(),
                             "ownedBy": ownedById.jsonArray()]
        
        return Event(type:type,
                     properties: ["pagedPublication": pubProperties as AnyObject])

    }
    
    static func publicationOpened(publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationEvent(type: "paged-publication-opened",
                                 publicationId: publicationId,
                                 ownedById: ownedById)
    }
    
    static func publicationAppeared(publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationEvent(type: "paged-publication-appeared",
                                 publicationId: publicationId,
                                 ownedById: ownedById)
    }
    
    static func publicationDisappeared(publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationEvent(type: "paged-publication-disappeared",
                                 publicationId: publicationId,
                                 ownedById: ownedById)
    }
    
    
    
    // MARK: Page Events
    
    private static func _publicationPageEvent(type:String, location:CGPoint?, pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        // TODO: fail if pageIndex is < 0
        // TODO: fail if location.x/y are not within 0-1 range
        
        let pubProperties = ["id": publicationId.jsonArray(),
                             "ownedBy": ownedById.jsonArray()]
        
        var pageProperties = ["pageNumber": (pageIndex + 1) as AnyObject]
        if let loc = location {
            pageProperties["x"] = loc.x as AnyObject
            pageProperties["y"] = loc.y as AnyObject
        }
        
        return Event(type:type,
                     properties: ["pagedPublication": pubProperties as AnyObject,
                                  "pagedPublicationPage": pageProperties as AnyObject])
    }

    static func publicationPageAppeared(pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationPageEvent(type: "paged-publication-page-appeared",
                                     location: nil,
                                     pageIndex:pageIndex,
                                     publicationId: publicationId,
                                     ownedById: ownedById)
    }
    
    static func publicationPageDisappeared(pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationPageEvent(type: "paged-publication-page-disappeared",
                                     location: nil,
                                     pageIndex:pageIndex,
                                     publicationId: publicationId,
                                     ownedById: ownedById)
    }
    
    static func publicationPageLoaded(pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationPageEvent(type: "paged-publication-page-loaded",
                                     location: nil,
                                     pageIndex:pageIndex,
                                     publicationId: publicationId,
                                     ownedById: ownedById)
    }
    
    
    
    // MARK: Page Interaction Events
    
    
    static func publicationPageClicked(location:CGPoint, pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationPageEvent(type: "paged-publication-page-clicked",
                                     location: location,
                                     pageIndex:pageIndex,
                                     publicationId: publicationId,
                                     ownedById: ownedById)
    }
    
    static func publicationPageHotspotsClicked(location:CGPoint, pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationPageEvent(type: "paged-publication-page-hotspots-clicked",
                                     location: location,
                                     pageIndex:pageIndex,
                                     publicationId: publicationId,
                                     ownedById: ownedById)
    }
    
    static func publicationPageDoubleClicked(location:CGPoint, pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationPageEvent(type: "paged-publication-page-double-clicked",
                                     location: location,
                                     pageIndex:pageIndex,
                                     publicationId: publicationId,
                                     ownedById: ownedById)
    }
    
    static func publicationPageLongPressed(location:CGPoint, pageIndex:Int, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationPageEvent(type: "paged-publication-page-long-pressed",
                                     location: location,
                                     pageIndex:pageIndex,
                                     publicationId: publicationId,
                                     ownedById: ownedById)
    }
    
    
    
    // MARK: Spread Events
    
    private static func _publicationSpreadEvent(type:String, pageIndexes:IndexSet, publicationId:IdField, ownedById:IdField) -> Event {
        
        // TODO: fail if pageIndexes.count < 1 or any pageIndex is < 0

        let pubProperties = ["id": publicationId.jsonArray(),
                             "ownedBy": ownedById.jsonArray()]
        
        let spreadProperties = ["pageNumbers": pageIndexes.map { $0 + 1 }]
        
        
        return Event(type:type,
                     properties: ["pagedPublication": pubProperties as AnyObject,
                                  "pagedPublicationPageSpread":spreadProperties as AnyObject])
        
    }
    
    static func publicationSpreadAppeared(pageIndexes:IndexSet, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationSpreadEvent(type: "paged-publication-page-spread-appeared",
                                       pageIndexes:pageIndexes,
                                       publicationId: publicationId,
                                       ownedById: ownedById)
    }
    
    static func publicationSpreadDisappeared(pageIndexes:IndexSet, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationSpreadEvent(type: "paged-publication-page-spread-disappeared",
                                       pageIndexes:pageIndexes,
                                       publicationId: publicationId,
                                       ownedById: ownedById)
    }
    
    static func publicationSpreadZoomedIn(pageIndexes:IndexSet, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationSpreadEvent(type: "paged-publication-page-spread-zoomed-in",
                                       pageIndexes:pageIndexes,
                                       publicationId: publicationId,
                                       ownedById: ownedById)
    }
    
    static func publicationSpreadZoomedOut(pageIndexes:IndexSet, publicationId:IdField, ownedById:IdField) -> Event {
        return _publicationSpreadEvent(type: "paged-publication-page-spread-zoomed-out",
                                       pageIndexes:pageIndexes,
                                       publicationId: publicationId,
                                       ownedById: ownedById)
    }
}
