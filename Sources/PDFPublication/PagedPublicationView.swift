//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

import Verso


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
    
    
    
    
    /// Tell the page publication that it is no longer visible.
    /// (eg. a view has been placed over the top of the PagedPublicationView, so the content is no longer visible)
    /// This will pause event collection, until `didEnterForeground` is called again.
    public func didEnterBackground() {
        for pageIndex in verso.currentPageIndexes {
            _pageDidDisappear(pageIndex)
        }
    }
    
    /// Tell the page publication that it is now visible again.
    /// (eg. when a view that was placed over the top of this view is removed, and the content becomes visible again).
    /// This will restart event collection. You MUST remember to call this if you previously called `didEnterBackground`, otherwise
    /// the PagePublicationView will not function correctly.
    public func didEnterForeground() {
        for pageIndex in verso.currentPageIndexes {
            _pageDidAppear(pageIndex)
        }
    }
    
    
    
    
    
    
    // MARK: Private
    
    
    private var pageCount:Int = 0
    private var outroPageIndex:Int? {
        get {
            return outroPageView != nil && pageCount > 0 ? pageCount : nil
        }
    }
    
    // MARK: - Private properties
    
    private var publicationViewModel:PagedPublicationViewModelProtocol?
    private var pageViewModels:[PagedPublicationPageViewModel]?
    private var hotspotsByPageIndex:[Int:[PagedPublicationHotspotViewModel]] = [:]
    
    lazy private var verso:VersoView = {
        let verso = VersoView()
        verso.dataSource = self
        verso.delegate = self
        return verso
    }()
    
    
    
    /// the view that is placed over the current spread
    private var hotspotOverlayView:HotspotOverlayView = HotspotOverlayView()
    
    
    
    /// The indexes of active pages that havnt been loaded yet. This set changes when pages are activated and deactivated, and when images are loaded
    /// Used by the PagedPublicationPageViewDelegate methods
    private var activePageIndexesWithPendingLoadEvents = NSMutableIndexSet()
    
    
    
    // MARK: Page Zooming
    
    /// a list of the pageIndexes that are activelty being zoomed (empty if not zoomed in)
    private var zoomedPageIndexes:NSIndexSet = NSIndexSet()
    
    private func _didZoomOut() {
        triggerEvent_PageSpreadZoomedOut(zoomedPageIndexes)
        zoomedPageIndexes = NSIndexSet()
    }
    
    private func _didZoomIn(zoomingPageIndexes:NSIndexSet) {
        triggerEvent_PageSpreadZoomedIn(zoomingPageIndexes)
        zoomedPageIndexes = zoomingPageIndexes
    }
    
    
    
    
    // MARK: Page Appearance/Disappearance
    
    
    
    @objc
    private func _didEnterBackgroundNotification(notification:NSNotification) {
        didEnterBackground()
    }
    @objc
    private func _willEnterForegroundNotification(notification:NSNotification) {
        didEnterForeground()
    }

    
    /// page indexes that have had the _appeared_ event triggered. when `disappeared` they are removed from here
    private var appearedPages:Set<Int> = []
    
    private func _pageDidAppear(pageIndex:Int) {
        guard appearedPages.contains(pageIndex) == false else {
            return
        }
        
        appearedPages.insert(pageIndex)
        
        
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
    
    private func _pageDidDisappear(pageIndex:Int) {
        
        guard appearedPages.contains(pageIndex) else {
            return
        }
        
        appearedPages.remove(pageIndex)
        
        
        activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
        
        // trigger a 'PAGE_DISAPPEARED event
        triggerEvent_PageDisappeared(pageIndex)
        
        
        // cancel the loading of the zoomimage
        if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView {
            pageView.clearZoomImage(animated: false)
        }
    }
}





// MARK: - VersoView DataSource

extension PagedPublicationView : VersoViewDataSource {

    public func configurePageForVerso(verso: VersoView, pageView: VersoPageView) {
        
        if let pubPage = pageView as? PagedPublicationPageView {
            
            let pageIndex = pubPage.pageIndex
            
            pubPage.delegate = self
            
            if let viewModel = pageViewModels?[sgn_safe:Int(pageIndex)] {
                
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
    

    public func adjustPreloadPageIndexesForVerso(verso: VersoView, visiblePageIndexes: NSIndexSet, preloadPageIndexes:NSIndexSet) -> NSIndexSet? {
        
        guard let realOutroPageIndex = outroPageIndex else {
            return nil
        }
        
        // add outro to preload page indexes if we have scrolled close to it
        let distToOutro = realOutroPageIndex - visiblePageIndexes.lastIndex
        if distToOutro < 10 {
            let adjustedPreloadPages = NSMutableIndexSet(indexSet: preloadPageIndexes)
            adjustedPreloadPages.addIndex(realOutroPageIndex)
            return adjustedPreloadPages
        }
        else {
            return nil
        }
    }
}

    



// MARK: - VersoView Delegate

extension PagedPublicationView : VersoViewDelegate {
    
    public func currentPageIndexesChangedForVerso(verso: VersoView, pageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {

        // pages changed while we were zoomed in - trigger a zoom-out event
        if zoomedPageIndexes.count > 0 && pageIndexes.isEqualToIndexSet(zoomedPageIndexes) == false {
            _didZoomOut()
        }
        
        // find the oldPageIndexes, and trigger change event if it was a change
        let oldPageIndexes = NSMutableIndexSet(indexSet:pageIndexes)
        oldPageIndexes.removeIndexes(added)
        oldPageIndexes.addIndexes(removed)
        if oldPageIndexes.count > 0 {
            triggerEvent_PageSpreadChanged(oldPageIndexes, newPageIndexes: pageIndexes)
        }
        
        
        // go through all the newly added page indexes, triggering `appeared` (and possibly `loaded`) events
        for pageIndex in added {
            // scrolling animation stopped and a new set of page Indexes are now visible.
            _pageDidAppear(pageIndex)
        }
        
        // go through all the newly removed page indexes, triggering `disappeared` events and removing them from pending list
        for pageIndex in removed {
            _pageDidDisappear(pageIndex)
        }
        
//        print ("current pages changed: \(pageIndexes.arrayOfAllIndexes())")
    }
    
    public func visiblePageIndexesChangedForVerso(verso: VersoView, pageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {
//        print ("visible pages changed: \(pageIndexes.arrayOfAllIndexes())")
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
                    let zoomImageURL = pageViewModels?[sgn_safe:pageIndex]?.zoomImageURL {
                    
                    // started zooming on a page with no zoom-image loaded.
                    pageView.startLoadingZoomImageFromURL(zoomImageURL)
                    
                }
            }
            
            
            
        }
        
        // Handle a weird case where we think we are zoomed in, but what we are no zoomed into
        // is not what we have just zoomed into (eg. some page layout happened that we didnt respond to)
        // In this case trigger a zoom out event for existing zoomed-in pages, and reset the zoomed-in page indexes
        if zoomedPageIndexes.isEqualToIndexSet(zoomingPageIndexes) == false && zoomedPageIndexes.count > 0 {
            _didZoomOut()
        }
        
        
        // We are not zoomed in and we are being told that Verso has zoomed in.
        // Trigger a zoom-in event, and remember that we have done so.
        if zoomedPageIndexes.count == 0 && zoomingPageIndexes.count > 0 && zoomScale > 1 {
            _didZoomIn(zoomingPageIndexes)
        }
        // We are now zoomed out fully of the pages we were previously zoomed into.
        // Trigger zoom-out event, and remember that we are now not zoomed in.
        else if zoomedPageIndexes.isEqualToIndexSet(zoomingPageIndexes) && zoomScale <= 1 {
            // there were some zoomed in pages, but now we have zoomed out, so trigger zoom-out event
            _didZoomOut()
        }
    }
    
}




    

    
// MARK: - PagedPublicationPage delegate

extension PagedPublicationView : PagedPublicationPageViewDelegate {
    
    public func didFinishLoadingImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool) {
        
        let pageIndex = pageView.pageIndex
        
        if activePageIndexesWithPendingLoadEvents.containsIndex(pageIndex),
            let viewModel = pageViewModels?[sgn_safe:pageIndex] where viewModel.defaultImageURL == imageURL {
            
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
//    public func didFinishLoadingZoomImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool) {
//    
//    }
    
//    public func didConfigure(pageView:PagedPublicationPageView, viewModel:PagedPublicationPageViewModelProtocol) {
//
//    }
}




extension PagedPublicationView : HotspotOverlayViewDelegate {
    
    func didTapHotspotOverlayView(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        triggerEvent_PageTapped(pageIndex, location: locationInPage)
        
    }
    func didLongPressHotspotOverlayView(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        triggerEvent_PageLongPressed(pageIndex, location: locationInPage)
        
        
        // debug page-jump when long-pressing
        var target = pageIndex + 10
        if target > pageCount {
            target = 0
        }
        verso.jumpToPage(target, animated: true)
        
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



