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
    
    let publicationId:String
    let ownerId:String
    let idSource:String
    
    init(publicationId:String, ownerId:String, idSource:String) {
        self.publicationId = publicationId
        self.ownerId = ownerId
        self.idSource = idSource
    }
    
    deinit {
        didDisappear()
    }
    
    // trigger an opened event
    func opened() {
        PublicationEvent_Opened(publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
    }
    
    
    
    fileprivate var hasAppeared:Bool = false
    
    func didAppear() {
        guard hasAppeared == false else { return }
        
        PublicationEvent_Appeared(publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
        
        spreadEventHandler?.didAppear()
        
        hasAppeared = true
    }
    
    func didDisappear() {
        guard hasAppeared == true else { return }
        
        spreadEventHandler?.didDisappear()
        
        PublicationEvent_Disappeared(publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
        
        hasAppeared = false
    }
    
    
    
    // MARK: Child event handlers
    
    func newSpreadEventHandler(for pageIndexes:IndexSet) {
        spreadEventHandler = SpreadLifecycleEventHandler(pageIndexes:pageIndexes, publicationId:self.publicationId, ownerId:self.ownerId, idSource:self.idSource)
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
    
    let publicationId:String
    let ownerId:String
    let idSource:String
    let pageIndexes:IndexSet
    
    init(pageIndexes:IndexSet, publicationId:String, ownerId:String, idSource:String) {
        self.publicationId = publicationId
        self.ownerId = ownerId
        self.idSource = idSource
        
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
        PublicationSpreadEvent_Appeared(pageIndexes:pageIndexes, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
        
        // then pages appear (and load if already loaded)
        for pageIndex in pageIndexes {
            
            PublicationPageEvent_Appeared(pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
            
            if loadedPageIndexes.contains(pageIndex) {
                
                PublicationPageEvent_Loaded(pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
            }
        }
        
        // finally zoom in (if already zoomed in)
        if isZoomedIn {
            PublicationSpreadEvent_ZoomedIn(pageIndexes:pageIndexes, publicationId:publicationId, ownedById:ownerId, idSource:idSource).track()
        }
        
        hasAppeared = true
    }
    
    fileprivate func didDisappear() {
        guard hasAppeared == true else { return }
        
        
        // first zoom out (if zoomed in)
        if isZoomedIn {
            PublicationSpreadEvent_ZoomedOut(pageIndexes:pageIndexes, publicationId:publicationId, ownedById:ownerId, idSource:idSource).track()
        }
        
        
        // disappear all the pages
        for pageIndex in pageIndexes.reversed() {
            PublicationPageEvent_Disappeared(pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
        }
        
        // disappear the spread
        PublicationSpreadEvent_Disappeared(pageIndexes:pageIndexes, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
        
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
        
        PublicationPageEvent_Loaded(pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
    }
    
    
    public func pageTapped(pageIndex:Int, location:CGPoint, hittingHotspots:Bool) {
        guard pageIndexes.contains(pageIndex) else {
            return
        }
        
        guard hasAppeared == true else {
            return
        }
        
        if hittingHotspots {
            PublicationPageInteractionEvent_HotspotsClicked(location:location, pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
        }
        else {
            PublicationPageInteractionEvent_Clicked(location:location, pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
        }
    }
    
    public func pageDoubleTapped(pageIndex:Int, location:CGPoint) {
        guard pageIndexes.contains(pageIndex) else {
            return
        }
        
        guard hasAppeared == true else {
            return
        }
        
        PublicationPageInteractionEvent_DoubleClicked(location:location, pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
    }
    
    public func pageLongPressed(pageIndex:Int, location:CGPoint) {
        guard pageIndexes.contains(pageIndex) else {
            return
        }
        
        guard hasAppeared == true else {
            return
        }
        
        PublicationPageInteractionEvent_LongPressed(location:location, pageIndex:pageIndex, publicationId: publicationId, ownedById:ownerId, idSource:idSource).track()
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
        
        PublicationSpreadEvent_ZoomedIn(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId, idSource: idSource).track()
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
        
        PublicationSpreadEvent_ZoomedOut(pageIndexes: pageIndexes, publicationId: publicationId, ownedById: ownerId, idSource: idSource).track()
    }
}





// MARK: Publication Events


/// Abstract superclass - must be subclassed
class PublicationEvent : EventProtocol, CustomDebugStringConvertible {
    let publicationId:String
    let ownedById:String
    let idSource:String
    
    init(publicationId:String, ownedById:String, idSource:String) {
        self.publicationId = publicationId
        self.ownedById = ownedById
        self.idSource = idSource
    }
    
    var type:String { fatalError("You must subclass this event, and implement type") }
    
    var properties:[String : AnyObject]? {
        var props:[String:AnyObject] = [:]
        
        props["pagedPublication"] = ["id": [idSource, publicationId] as AnyObject,
                                     "ownedBy": [idSource, ownedById]  as AnyObject] as AnyObject
        return props
    }
    
    public var debugDescription: String {
        return "PubEvent [\(publicationId)] \(type)"
    }
}

class PublicationEvent_Opened : PublicationEvent {
    override var type:String { return "paged-publication-opened" }
}
class PublicationEvent_Appeared : PublicationEvent {
    override var type:String { return "paged-publication-appeared" }
}
class PublicationEvent_Disappeared : PublicationEvent {
    override var type:String { return "paged-publication-disappeared" }
}

// MARK: Page Events

/// Abstract superclass - must be subclassed
class PublicationPageEvent : PublicationEvent {
    let pageIndex:Int
    
    init(pageIndex:Int, publicationId: String, ownedById: String, idSource: String) {
        self.pageIndex = pageIndex
        // TODO: fail if pageIndex is < 0
        
        super.init(publicationId: publicationId, ownedById: ownedById, idSource: idSource)
    }
    
    override var properties:[String : AnyObject]? {
        var props:[String:AnyObject] = super.properties ?? [:]
        
        props["pagedPublicationPage"] = ["pageNumber": pageIndex + 1] as AnyObject
        
        return props
    }
    
    override public var debugDescription: String {
        return "PubEvent [\(publicationId)] \(type) page:\(pageIndex+1)"
    }
}

class PublicationPageEvent_Appeared : PublicationPageEvent {
    override var type:String { return "paged-publication-page-appeared" }
}
class PublicationPageEvent_Disappeared : PublicationPageEvent {
    override var type:String { return "paged-publication-page-disappeared" }
}
class PublicationPageEvent_Loaded : PublicationPageEvent {
    override var type:String { return "paged-publication-page-loaded" }
}


// MARK: Page Interaction Events

/// Abstract superclass - must be subclassed
class PublicationPageInteractionEvent : PublicationPageEvent {
    let location:CGPoint
    
    init(location:CGPoint, pageIndex: Int, publicationId: String, ownedById: String, idSource: String) {
        self.location = location
        // TODO: fail if location.x/y are not within 0-1 range

        super.init(pageIndex: pageIndex, publicationId: publicationId, ownedById: ownedById, idSource: idSource)
    }
    
    override var properties:[String : AnyObject]? {
        var props:[String:AnyObject] = super.properties ?? [:]
        
        var pubPageProperties = props["pagedPublicationPage"] as? [String:AnyObject] ?? [:]
        
        pubPageProperties["x"] = location.x as AnyObject
        pubPageProperties["y"] = location.y as AnyObject
        
        props["pagedPublicationPage"] = pubPageProperties as AnyObject
        
        return props
    }
    
    override public var debugDescription: String {
        return "PubEvent [\(publicationId)] \(type) page:\(pageIndex+1) location:[\(location.x),\(location.y)]"
    }
}

class PublicationPageInteractionEvent_Clicked : PublicationPageInteractionEvent {
    override var type:String { return "paged-publication-page-clicked" }
}
class PublicationPageInteractionEvent_HotspotsClicked : PublicationPageInteractionEvent {
    override var type:String { return "paged-publication-page-hotspots-clicked" }
}
class PublicationPageInteractionEvent_DoubleClicked : PublicationPageInteractionEvent {
    override var type:String { return "paged-publication-page-double-clicked" }
}
class PublicationPageInteractionEvent_LongPressed : PublicationPageInteractionEvent {
    override var type:String { return "paged-publication-page-long-pressed" }
}




// MARK: Spread Events

/// Abstract superclass - must be subclassed
class PublicationSpreadEvent : PublicationEvent {
    let pageIndexes:IndexSet
    
    init(pageIndexes:IndexSet, publicationId: String, ownedById: String, idSource: String) {
        self.pageIndexes = pageIndexes
        // TODO: fail if pageIndexes.count < 1 or any pageIndex is < 0
        
        super.init(publicationId: publicationId, ownedById: ownedById, idSource: idSource)
    }
    
    override var properties:[String : AnyObject]? {
        var props:[String:AnyObject] = super.properties ?? [:]
        
        var pageNumbersArray = [Int]()
        pageIndexes.forEach { (idx) in
            pageNumbersArray.append(idx + 1)
        }
        props["pagedPublicationPageSpread"] = ["pageNumbers": pageNumbersArray] as AnyObject
        
        return props
    }
    
    override public var debugDescription: String {
        
        var pageNumbersArray = [Int]()
        pageIndexes.forEach { (idx) in
            pageNumbersArray.append(idx + 1)
        }
        return "PubEvent [\(publicationId)] \(type) pages:\(pageNumbersArray)"
    }
}

class PublicationSpreadEvent_Appeared : PublicationSpreadEvent {
    override var type:String { return "paged-publication-page-spread-appeared" }
}
class PublicationSpreadEvent_Disappeared : PublicationSpreadEvent {
    override var type:String { return "paged-publication-page-spread-disappeared" }
}
class PublicationSpreadEvent_ZoomedIn : PublicationSpreadEvent {
    override var type:String { return "paged-publication-page-spread-zoomed-in" }
}
class PublicationSpreadEvent_ZoomedOut : PublicationSpreadEvent {
    override var type:String { return "paged-publication-page-spread-zoomed-out" }
}

