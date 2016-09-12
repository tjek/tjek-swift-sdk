//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

import AlamofireImage

@objc(SGNPagedPublicationView)
public class PagedPublicationView : UIView {

    public override init(frame: CGRect) {
        super.init(frame:frame)
        
        
        // setup notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PagedPublicationView._didEnterBackgroundNotification(_:)), name: UIApplicationDidEnterBackgroundNotification, object: nil)        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PagedPublicationView._willEnterForegroundNotification(_:)), name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        
        backgroundColor = UIColor.whiteColor()
        
        verso.frame = frame
        verso.clipsToBounds = false
        verso.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        addSubview(verso)
        
        
        
        // FIXME: dont do this
        AlamofireImage.ImageDownloader.defaultURLCache().removeAllCachedResponses()
        AlamofireImage.ImageDownloader.defaultInstance.imageCache?.removeAllImages()
        
    }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidEnterBackgroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillEnterForegroundNotification, object: nil)
    }
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        verso.frame = bounds
    }
    
    
    
    
    // MARK: - Public
    
    
    // TODO: setting this will trigger changes
    public func updateWithPublicationViewModel(viewModel:PagedPublicationViewModelProtocol?) {
        
        publicationViewModel = viewModel
        
        pageCount = publicationViewModel?.pageCount ?? 0
        
        verso.backgroundColor = viewModel?.bgColor
        
        // TODO: do we clear the pageviewmodels if this is updated again?
        
        // force a re-fetch of the pageCount
        verso.reloadPages()
    }
    
    public func updatePages(viewModels:[PagedPublicationPageViewModel]?) {
        
        let publicationAspectRatio = publicationViewModel?.aspectRatio ?? 1.0
        
        if viewModels != nil {
            for viewModel in viewModels! {
                if viewModel.aspectRatio <= 0 {
                    viewModel.aspectRatio = publicationAspectRatio
                }
            }
        }
        
        pageViewModels = viewModels
        
        let newPageCount = pageViewModels?.count ?? 0
        if newPageCount != pageCount {
            pageCount = newPageCount
            
            // force a re-fetch of the pageCount
            verso.reloadPages()
        }
        else {
            // just re-config the visible pages if pagecount didnt change
            verso.reconfigureVisiblePages()
        }
    }
    
    
    public func updateHotspots(viewModels:[PagedPublicationHotspotViewModel]?) {
        
        var newHotspotsByPageIndex:[Int:[PagedPublicationHotspotViewModel]] = [:]
        
        if viewModels != nil {
            for hotspotModel in viewModels! {
                let hotspotPageIndexes = hotspotModel.getPageIndexes()
                
                for pageIndex in hotspotPageIndexes {
                    var hotspotsForPage = newHotspotsByPageIndex[pageIndex] ?? []
                    hotspotsForPage.append(hotspotModel)
                    newHotspotsByPageIndex[pageIndex] = hotspotsForPage
                }
            }
        }
        hotspotsByPageIndex = newHotspotsByPageIndex
        
        verso.reconfigureSpreadOverlay()
    }
    
    
    private var pageCount:Int = 0
    private var outroPageIndex:Int? {
        get {
            return pageCount > 0 ? pageCount : nil
        }
    }
    
    

    // MARK: - Private properties
    
    private var publicationViewModel:PagedPublicationViewModelProtocol?
    private var pageViewModels:[PagedPublicationPageViewModel]?
    private var hotspotsByPageIndex:[Int:[PagedPublicationHotspotViewModel]] = [:]
    
    /// The indexes of active pages that havnt been loaded yet. This set changes when pages are activated and deactivated, and when images are loaded
    /// Used by the PagedPublicationPageViewDelegate methods
    private var activePageIndexesWithPendingLoadEvents = NSMutableIndexSet()
    
    /// the indexes of the pages that are loading their zoom images.
    /// This is reset whenever active pages change
    private var pageIndexesLoadingZoomImage = NSMutableIndexSet()
    
    lazy private var verso:VersoView = {
        let verso = VersoView()
        verso.dataSource = self
        verso.delegate = self
        return verso
    }()
    
    
    
    // MARK: Notification handlers
    func _didEnterBackgroundNotification(notification:NSNotification) {
        for pageIndex in verso.lastActivePageIndexes {
            triggerEvent_PageDisappeared(pageIndex)
        }
    }
    func _willEnterForegroundNotification(notification:NSNotification) {
        for pageIndex in verso.lastActivePageIndexes {
            _pageDidAppear(pageIndex)
        }
    }
    
    
    private var hotspotOverlayView:HotspotOverlayView = HotspotOverlayView()
}





// MARK: - VersoView DataSource

extension PagedPublicationView : VersoViewDataSource {

    public func configurePageForVerso(verso: VersoView, pageView: VersoPageView) {
        
        if let pubPage = pageView as? PagedPublicationPageView {
            
            let pageIndex = pubPage.pageIndex
            
            pubPage.delegate = self
            
            if let viewModel = pageViewModels?[safe:Int(pageIndex)] {
                
                // valid view model
                pubPage.configure(viewModel)
            }                
            else
            {
                let aspectRatio = publicationViewModel?.aspectRatio ?? 1.0
                
                // build blank view model
                let viewModel = PagedPublicationPageViewModel(pageIndex:pageIndex, pageTitle:String(pageIndex+1), aspectRatio: aspectRatio)
                
                pubPage.configure(viewModel)
            }
        }
        else if let labelPage = pageView as? LabelledVersoPageView {
            labelPage.pageLabel.text = String(labelPage.pageIndex)
            labelPage.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.3)
        }
    }
    
    public func pageViewClassForVerso(verso:VersoView, pageIndex:Int) -> VersoPageViewClass {
        if outroPageIndex == pageIndex {
            return LabelledVersoPageView.self
        }
        else {
            return PagedPublicationPageView.self
        }
//        outroPageIndex != nil && 
//        if let pageCount = verso.spreadConfiguration?.pageCount where pageIndex == pageCount-1 {
//            return LabelledVersoPageView.self
//        } else {
//            return PagedPublicationPageView.self
//        }
    }
    
    
    public func spreadConfigurationForVerso(verso:VersoView, size:CGSize) -> VersoSpreadConfiguration {
        
        // TODO: compare verso aspect ratio to publication aspect ratio
        //        let versoAspectRatio = size.height > 0 ? size.width / size.height : 1
        //        let isVersoPortrait = versoAspectRatio < 1
        //        if let contentAspectRatio = publicationViewModel?.aspectRatio {
        //
        //        }

        let totalPageCount = pageCount == 0 ? 0 : pageCount + 1
        let outroIndex = outroPageIndex
        let lastPageIndex = max((outroIndex != nil ? (outroIndex! - 1) : pageCount - 1), 0)
        
        
        let isLandscape:Bool = size.width > size.height
        
        return VersoSpreadConfiguration.buildPageSpreadConfiguration(totalPageCount, spreadSpacing: 20, spreadPropertyConstructor: { (spreadIndex, nextPageIndex) -> (spreadPageCount: Int, maxZoomScale: CGFloat, widthPercentage: CGFloat) in
            
            let isFirstPage = nextPageIndex == 0
            let isOutro = outroIndex == nextPageIndex
            let isLastPage = nextPageIndex == lastPageIndex
            
            
            let isSinglePage = isFirstPage || isOutro || isLastPage || !isLandscape
            
            let spreadPageCount = isSinglePage ? 1 : 2
            
            let outroWidth:CGFloat = isLandscape ? 0.8 : 0.7
            
            return (spreadPageCount, isOutro ? 0.0 : 4.0, isOutro ? outroWidth : 1.0)
        })
    }
    
    
    public func spreadOverlayViewForVerso(verso: VersoView, overlaySize: CGSize, pageFrames: [Int : CGRect]) -> UIView? {
        
        // no overlay for outro
        if outroPageIndex != nil && pageFrames[outroPageIndex!] != nil {
            return nil
        }
        
        // configure the overlay
        var spreadHotspots:[PagedPublicationHotspotViewModel] = []
        for (pageIndex, _) in pageFrames {
            if let hotspots = hotspotsByPageIndex[pageIndex] {
                for hotspot in hotspots {
                    if spreadHotspots.contains(hotspot) == false {
                        spreadHotspots.append(hotspot)
                    }
                }
            }
        }
        if spreadHotspots.count == 0 {
            return nil
        }
        
        hotspotOverlayView.delegate = self
        hotspotOverlayView.frame.size = overlaySize
        hotspotOverlayView.updateWithHotspots(spreadHotspots, pageFrames: pageFrames)        
        
        // disable tap when double-tapping
        if let doubleTap = verso.zoomDoubleTapGestureRecognizer {
            hotspotOverlayView.tapGesture?.requireGestureRecognizerToFail(doubleTap)
        }
        
        return hotspotOverlayView
    }
}

    



// MARK: - VersoView Delegate

extension PagedPublicationView : VersoViewDelegate {
    
    private func _pageDidAppear(pageIndex:Int) {
        
        // scrolling animation stopped and a new set of page Indexes are now visible.
        // trigger 'PAGE_APPEARED' event
        triggerEvent_PageAppeared(pageIndex)
        
        
        // if image loaded then trigger 'PAGE_LOADED' event
        if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
            where pageView.imageLoadState == .Loaded {
            
            triggerEvent_PageLoaded(pageIndex, fromCache: true)
        }
        else {
            // page became active but image hasnt yet loaded... keep track of it
            activePageIndexesWithPendingLoadEvents.addIndex(Int(pageIndex))
        }
    }
    
    public func activePagesDidChangeForVerso(verso: VersoView, activePageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {
        
        print ("active pages changed: \(activePageIndexes.arrayOfAllIndexes())")
        
        // go through all the newly added page indexes, triggering `appeared` (and possibly `loaded`) events
        for pageIndex in added {
            // scrolling animation stopped and a new set of page Indexes are now visible.
            
            _pageDidAppear(pageIndex)
        }
        
        // go through all the newly removed page indexes, triggering `disappeared` events and removing them from pending list
        for pageIndex in removed {
            activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
            
            // trigger a 'PAGE_DISAPPEARED event
            triggerEvent_PageDisappeared(pageIndex)

            
            // cancel the loading of the zoomimage
            if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView {
                pageView.clearZoomImage(animated: false)
            }
        }
    }
    
    public func currentPagesDidChangeForVerso(verso: VersoView, currentPageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {
        
        // TODO: start pre-warming images if we scroll past a certain point (and dont scroll back again within a time-frame)
//        print ("current pages changed: \(currentPageIndexes.arrayOfAllIndexes())")
    }
    
    
    public func didStartZoomingPagesForVerso(verso: VersoView, zoomingPageIndexes: NSIndexSet, zoomScale: CGFloat) {
        
//        print ("did start zooming \(zoomScale) \(zoomingPageIndexes.arrayOfAllIndexes())")
        
    }
    
    public func didZoomPagesForVerso(verso: VersoView, zoomingPageIndexes: NSIndexSet, zoomScale: CGFloat) {
        
//        print ("did zoom \(zoomScale) \(zoomingPageIndexes.arrayOfAllIndexes())")
        
    }
    
    public func didEndZoomingPagesForVerso(verso: VersoView, zoomingPageIndexes: NSIndexSet, zoomScale: CGFloat) {
        
        if zoomScale > 1 {
            
            for pageIndex in zoomingPageIndexes {
                if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
                    where pageView.zoomImageLoadState == .NotLoaded,
                    let zoomImageURL = pageViewModels?[safe:pageIndex]?.zoomImageURL {
                    
                    // started zooming on a page with no zoom-image loaded.
                    pageView.startLoadingZoomImageFromURL(zoomImageURL)
                    
                }
            }
        }
        
//        print ("did end zooming \(zoomScale) \(zoomingPageIndexes.arrayOfAllIndexes())")
    }
    
}
    

    
    
    

    
// MARK: - PagedPublicationPage delegate

extension PagedPublicationView : PagedPublicationPageViewDelegate {
 
//    public func didConfigurePagedPublicationPage(pageView:PagedPublicationPageView, viewModel:PagedPublicationPageViewModelProtocol) {
//        
//    }
    
    public func didLoadPagedPublicationPageImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool) {
        
        let pageIndex = pageView.pageIndex
        
        if activePageIndexesWithPendingLoadEvents.containsIndex(pageIndex),
            let viewModel = pageViewModels?[safe:pageIndex] where viewModel.defaultImageURL == imageURL {
            
            // the page is active, and has not yet had its image loaded.
            // and the image url is the same as that of the viewModel at that page Index (view model hasnt changed since)
            // so trigger 'PAGE_LOADED' event
            // Only do this if the app is active - otherwise, when the app went into the background, we have sent a disappeared event
            if UIApplication.sharedApplication().applicationState == .Active {
                triggerEvent_PageLoaded(pageIndex, fromCache: fromCache)
            }
            
            activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
        }
    }
//    public func didLoadPagedPublicationPageZoomImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool) {
//    
//    }
}




extension PagedPublicationView : HotspotOverlayViewDelegate {
    
    func didTapHotspotsInOverlayView(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationHotspotViewModelProtocol], hotspotViews: [UIView], locationInOverlay: CGPoint) {
//        triggerEvent_PageTapped(pageView.pageIndex, location: location)
        print ("Tapped! \(hotspots.count)")
    }
    
    func didLongPressHotspotsInOverlayView(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationHotspotViewModelProtocol], hotspotViews: [UIView], locationInOverlay: CGPoint) {
        
//        triggerEvent_PageLongPressed(pageView.pageIndex, location: location, duration:duration)

        print ("LongPress! \(hotspots.count)")
    }
    
}





// MARK: - Event Handling

// TODO: move to another file
extension PagedPublicationView {
    
    func triggerEvent_PageAppeared(pageIndex:Int) {
        print("[EVENT] Page Appeared(\(pageIndex))")
    }
    func triggerEvent_PageLoaded(pageIndex:Int,fromCache:Bool) {
        print("[EVENT] Page Loaded\(pageIndex) cache:\(fromCache)")
    }
    func triggerEvent_PageDisappeared(pageIndex:Int) {
        print("[EVENT] Page Disappeared(\(pageIndex))")
    }
//    func triggerEvent_PagesChanged(fromPageIndexes:NSIndexSet, toPageIndexes:NSIndexSet) {
//        // TODO: page Changed events
//        print("[EVENT] Page Changed(\(fromPageIndexes.arrayOfAllIndexes()) -> \(toPageIndexes.arrayOfAllIndexes()))")
//    }
    
    
    func triggerEvent_PageZoomedIn(pageIndexes:NSIndexSet, centerPoint:CGPoint) {
//        print("[EVENT] Page Zoomed In(\(pageIndexes.arrayOfAllIndexes())) \(centerPoint)")
    }
    func triggerEvent_PageZoomedOut(pageIndexes:NSIndexSet, centerPoint:CGPoint) {
//        print("[EVENT] Page Zoomed Out(\(pageIndexes.arrayOfAllIndexes())) \(centerPoint)")
    }
    
    
    func triggerEvent_PageTapped(pageIndex:Int, location:CGPoint) {
//        print("[EVENT] Page Tapped(\(pageIndex)) \(location)")
    }
    func triggerEvent_PageLongPressed(pageIndex:Int, location:CGPoint, duration:NSTimeInterval) {
//        print("[EVENT] Page LongPressed(\(pageIndex)) \(location)")
    }
}


//enum PagedPublicationEventType {
//    case Opened(id:String, pageNumber:Int, pageCount:Int)
//    
//    
//    // TODO: func to get properties dict & type name
//}












// MARK: - Fetching
// TODO: move to another file
public extension PagedPublicationView {
    
    // uses graphKit to fetch the PagedPublication for the specified publicationId
    public func fetchContents(publicationId:String) {
        // put it in a `fetching` state
        
        
        
        // TODO: perform the request with GraphKit
        
        // TODO: update publicationVM
//        updateWithPublicationViewModel(nil)
        
    }
    
}




// Debug utilty for printing out indexSets
extension NSIndexSet {
    func arrayOfAllIndexes() -> [Int] {
        var allIndexes = [Int]()
        enumerateIndexesUsingBlock { (idx, stop) in
            allIndexes.append(idx)
        }
        return allIndexes
    }
}



