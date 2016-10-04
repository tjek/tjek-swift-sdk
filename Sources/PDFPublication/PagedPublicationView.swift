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

public protocol PagedPublicationViewDelegate : class {
    
    
    func didTapPage(pagedPublicationView:PagedPublicationView, pageIndex:Int, locationInPage:CGPoint, hotspots:[PagedPublicationHotspotViewModelProtocol])
    func didLongPressPage(pagedPublicationView:PagedPublicationView, pageIndex:Int, locationInPage:CGPoint, hotspots:[PagedPublicationHotspotViewModelProtocol])
}

// default no-op
public extension PagedPublicationViewDelegate {
    func didTapPage(pagedPublicationView:PagedPublicationView, pageIndex:Int, locationInPage:CGPoint, hotspots:[PagedPublicationHotspotViewModelProtocol]) {}
    func didLongPressPage(pagedPublicationView:PagedPublicationView, pageIndex:Int, locationInPage:CGPoint, hotspots:[PagedPublicationHotspotViewModelProtocol]) {}
}

public protocol PagedPublicationViewDataSource : PagedPublicationViewDataSourceOptional {
}

public typealias OutroView = VersoPageView
public protocol PagedPublicationViewDataSourceOptional : class {
    
    func outroViewClass(pagedPublicationView:PagedPublicationView, size:CGSize) -> (OutroView.Type)?
    func configureOutroView(pagedPublicationView:PagedPublicationView, outroView:OutroView)
    func outroViewWidth(pagedPublicationView:PagedPublicationView, size:CGSize) -> CGFloat
    func outroViewMaxZoom(pagedPublicationView:PagedPublicationView, size:CGSize) -> CGFloat

    func textForPageNumberLabel(pagedPublicationView:PagedPublicationView, pageIndexes:IndexSet, pageCount:Int) -> String?
}

// Default values for datasource
public extension PagedPublicationViewDataSourceOptional {
    func configureOutroView(pagedPublicationView:PagedPublicationView, outroView:VersoPageView) { }
    func outroViewClass(pagedPublicationView:PagedPublicationView, size:CGSize) -> (OutroView.Type)? {
        return nil
    }
    func outroViewWidth(pagedPublicationView:PagedPublicationView, size:CGSize) -> CGFloat {
        return 0.9
    }
    func outroViewMaxZoom(pagedPublicationView:PagedPublicationView, size:CGSize) -> CGFloat {
        return 1.0
    }
    func textForPageNumberLabel(pagedPublicationView:PagedPublicationView, pageIndexes:IndexSet, pageCount:Int) -> String? {
        if pageIndexes.count == 1 {
            return "\(pageIndexes.first!+1) / \(pageCount)"
        }
        else if pageIndexes.count > 1 {
            return "\(pageIndexes.first!+1)-\(pageIndexes.last!+1) / \(pageCount)"
        }
        return nil
    }
}
/// Have PagedPublicationView as the source of the default optional values, for when dataSource is nil.
extension PagedPublicationView : PagedPublicationViewDataSourceOptional {}



@objc(SGNPagedPublicationView)
open class PagedPublicationView : UIView {

    public override init(frame: CGRect) {
        super.init(frame:frame)
        
        
        // setup notifications
        NotificationCenter.default.addObserver(self, selector: #selector(PagedPublicationView._didEnterBackgroundNotification(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)        
        NotificationCenter.default.addObserver(self, selector: #selector(PagedPublicationView._willEnterForegroundNotification(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        
        backgroundColor = UIColor.white
        
        verso.frame = frame
        verso.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(verso)
        
        addSubview(pageNumberLabel)
        pageNumberLabel.alpha = 0
    }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        verso.frame = bounds
        
        layoutPageNumberLabel()
    }
    
    
    
    
    // MARK: - Public
    open weak var dataSource:PagedPublicationViewDataSource?
    
    open weak var delegate:PagedPublicationViewDelegate?
    
    public fileprivate(set) var pageCount:Int = 0
    
    
    // TODO: setting this will trigger changes
    open func update(publication viewModel:PagedPublicationViewModelProtocol?, targetPageIndex:Int = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            
            
            s.publicationViewModel = viewModel
            
            s.pageCount = s.publicationViewModel?.pageCount ?? 0
            
            UIView.animate(withDuration: 0.2, animations: {
                s.backgroundColor = viewModel?.bgColor
            })
            // TODO: do we clear the pageviewmodels if this is updated again?
            
            // force a re-fetch of the pageCount
            s.verso.reloadPages(targetPageIndex:targetPageIndex)
        }
    }
    
    open func update(pages viewModels:[PagedPublicationPageViewModel]?) {
        
        if viewModels != nil, let publicationAspectRatio = publicationViewModel?.aspectRatio {
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
    
    
    open func update(hotspots viewModels:[PagedPublicationHotspotViewModel]?) {
        
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
    
    public func jump(toPageIndex pageIndex:Int, animated:Bool) {
        verso.jump(toPageIndex: pageIndex, animated: animated)
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
    
    /// A neat trick to allow pure-swift optional protocol methods: http://blog.stablekernel.com/optional-protocol-methods-in-pure-swift
    fileprivate var dataSourceOptional: PagedPublicationViewDataSourceOptional {
        return dataSource ?? self
    }
    
    fileprivate var outroViewProperties:(viewClass:(OutroView.Type)?, width:CGFloat, maxZoom:CGFloat) = (nil, 1.0, 1.0)
    fileprivate var outroPageIndex:Int? {
        get {
            return outroViewProperties.viewClass != nil && pageCount > 0 ? pageCount : nil
        }
    }
    
    public fileprivate(set) var publicationViewModel:PagedPublicationViewModelProtocol?
    public fileprivate(set) var pageViewModels:[PagedPublicationPageViewModel]?
    public fileprivate(set) var hotspotsByPageIndex:[Int:[PagedPublicationHotspotViewModel]] = [:]
    
    lazy fileprivate var verso:VersoView = {
        let verso = VersoView()
        verso.dataSource = self
        verso.delegate = self
        return verso
    }()
    
    
    fileprivate var pageNumberLabel:PageNumberLabel = PageNumberLabel()
    class PageNumberLabel : UILabel {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            layer.cornerRadius = 6
            layer.masksToBounds = true
            textColor = UIColor.white
            backgroundColor = UIColor(white: 0, alpha: 0.3)
            
            textAlignment = .center
            font = UIFont.boldSystemFont(ofSize: 18) //TODO: dynamic font size

            numberOfLines = 1
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        // MARK: Edge Insets
        var labelEdgeInsets:UIEdgeInsets = UIEdgeInsetsMake(4, 22, 4, 22)
        
        override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
            var rect = super.textRect(forBounds: UIEdgeInsetsInsetRect(bounds, labelEdgeInsets), limitedToNumberOfLines: numberOfLines)
            
            rect.origin.x -= labelEdgeInsets.left
            rect.origin.y -= labelEdgeInsets.top
            rect.size.width += labelEdgeInsets.left + labelEdgeInsets.right
            rect.size.height += labelEdgeInsets.top + labelEdgeInsets.bottom
            
            return rect
        }
        override func drawText(in rect: CGRect) {
            super.drawText(in: UIEdgeInsetsInsetRect(rect, labelEdgeInsets))
        }
    }
    
    fileprivate func layoutPageNumberLabel() {
        
        // layout page number label
        var lblFrame = pageNumberLabel.frame
        lblFrame.size = pageNumberLabel.sizeThatFits(bounds.size)
        lblFrame.origin.x = round(bounds.midX - (lblFrame.width / 2))
        lblFrame.origin.y = round(bounds.maxY - 11 - lblFrame.height)
        pageNumberLabel.frame = lblFrame
    }
    
    @objc
    fileprivate func hidePageNumberLabel() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.beginFromCurrentState], animations: { 
            self.pageNumberLabel.alpha = 0.2
            }, completion: nil)
    }
    
    fileprivate func showPageNumberLabel() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(PagedPublicationView.hidePageNumberLabel), object: nil)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState], animations: {
            self.pageNumberLabel.alpha = 1.0
            }, completion: nil)
        
        self.perform(#selector(PagedPublicationView.hidePageNumberLabel), with: nil, afterDelay: 1.0)
    }
    
    fileprivate func updatePageNumberLabel(withText text:String?) {
        if text == nil {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
                self.pageNumberLabel.alpha = 0
            }) { (finished) in
                if finished {
                    self.pageNumberLabel.text = nil
                }
            }
        }
        else {
            if pageNumberLabel.text == nil {
                pageNumberLabel.text = text
                layoutPageNumberLabel()
            } else {
                UIView.transition(with: pageNumberLabel, duration: 0.15, options: [.transitionCrossDissolve, .beginFromCurrentState], animations: {
                    self.pageNumberLabel.text = text
                    self.layoutPageNumberLabel()
                })
            }
            
            showPageNumberLabel()
        }
    }
    
    
    
    
    
    /// the view that is placed over the current spread
    fileprivate var hotspotOverlayView:HotspotOverlayView = HotspotOverlayView()
    
    
    
    /// The indexes of active pages that havnt been loaded yet. This set changes when pages are activated and deactivated, and when images are loaded
    /// Used by the PagedPublicationPageViewDelegate methods
    fileprivate var activePageIndexesWithPendingLoadEvents = NSMutableIndexSet()
    
    
    
    // MARK: Page Zooming
    
    /// a list of the pageIndexes that are activelty being zoomed (empty if not zoomed in)
    fileprivate var zoomedPageIndexes:IndexSet = IndexSet()
    
    fileprivate func _didZoomOut() {
        triggerEvent_PageSpreadZoomedOut(zoomedPageIndexes)
        zoomedPageIndexes = IndexSet()
    }
    
    fileprivate func _didZoomIn(_ zoomingPageIndexes:IndexSet) {
        triggerEvent_PageSpreadZoomedIn(zoomingPageIndexes)
        zoomedPageIndexes = zoomingPageIndexes
    }
    
    
    
    
    // MARK: Page Appearance/Disappearance
    
    @objc
    fileprivate func _didEnterBackgroundNotification(_ notification:Notification) {
        didEnterBackground()
    }
    @objc
    fileprivate func _willEnterForegroundNotification(_ notification:Notification) {
        didEnterForeground()
    }

    
    /// page indexes that have had the _appeared_ event triggered. when `disappeared` they are removed from here
    fileprivate var appearedPages:Set<Int> = []
    
    fileprivate func _pageDidAppear(_ pageIndex:Int) {
        guard appearedPages.contains(pageIndex) == false else {
            return
        }
        
        appearedPages.insert(pageIndex)
        
        
        // scrolling animation stopped and a new set of page Indexes are now visible.
        // trigger 'PAGE_APPEARED' event
        triggerEvent_PageAppeared(pageIndex)
        
        
        // if image loaded then trigger 'PAGE_LOADED' event
        if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView,
            pageView.imageLoadState == .loaded {
            
            triggerEvent_PageLoaded(pageIndex, fromCache: true)
        }
        else {
            // page became active but image hasnt yet loaded... keep track of it
            activePageIndexesWithPendingLoadEvents.add(pageIndex)
        }
    }
    
    fileprivate func _pageDidDisappear(_ pageIndex:Int) {
        
        guard appearedPages.contains(pageIndex) else {
            return
        }
        
        appearedPages.remove(pageIndex)
        
        
        activePageIndexesWithPendingLoadEvents.remove(pageIndex)
        
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

    public func configurePage(verso: VersoView, pageView: VersoPageView) {
        
        if let pubPage = pageView as? PagedPublicationPageView {
            
            let pageIndex = pubPage.pageIndex
            
            pubPage.delegate = self
            
            var whiteComponent:CGFloat = 1.0
            publicationViewModel?.bgColor.getWhite(&whiteComponent, alpha: nil)
            
            // TODO: use cuttlefish?
            let bgIsDark = whiteComponent > 0.6 ? false : true
            
            if let viewModel = pageViewModels?[sgn_safe:Int(pageIndex)] {
                
                // valid view model
                pubPage.configure(viewModel, darkBG:bgIsDark)
            }                
            else
            {
                let aspectRatio = publicationViewModel?.aspectRatio ?? 1.0
                
                // build blank view model
                let viewModel = PagedPublicationPageViewModel(pageIndex:pageIndex, pageTitle:String(pageIndex+1), aspectRatio: aspectRatio)
                
                pubPage.configure(viewModel, darkBG:bgIsDark)
            }
        }
        else if type(of: pageView) === self.outroViewProperties.viewClass {
            dataSourceOptional.configureOutroView(pagedPublicationView: self, outroView: pageView)
        }
    }
    
    public func pageViewClass(verso:VersoView, pageIndex:Int) -> VersoPageViewClass {
        if outroPageIndex == pageIndex {
            return outroViewProperties.viewClass ?? VersoPageView.self
        }
        else {
            return PagedPublicationPageView.self
        }
    }
    
    public func spreadConfiguration(verso:VersoView, size:CGSize) -> VersoSpreadConfiguration {
        
        // update outro properties from datasource
        outroViewProperties = (dataSourceOptional.outroViewClass(pagedPublicationView: self, size:size),
                               dataSourceOptional.outroViewWidth(pagedPublicationView: self, size:size),
                               dataSourceOptional.outroViewMaxZoom(pagedPublicationView: self, size:size))
        
        let outroIndex = outroPageIndex
        let totalPageCount = pageCount > 0 && outroIndex != nil ? pageCount + 1 : pageCount
        
        
        let lastPageIndex = max((outroIndex != nil ? (outroIndex! - 1) : pageCount - 1), 0)
        
        let spreadSpacing:CGFloat = 20
        
        // TODO: compare verso aspect ratio to publication aspect ratio
        let isLandscape:Bool = size.width > size.height
        
        
        return VersoSpreadConfiguration.buildPageSpreadConfiguration(pageCount: totalPageCount, spreadSpacing: spreadSpacing, spreadPropertyConstructor: { (spreadIndex, nextPageIndex) -> (spreadPageCount: Int, maxZoomScale: CGFloat, widthPercentage: CGFloat) in
            
            // it's the outro
            if outroIndex == nextPageIndex {
                return (1, self.outroViewProperties.maxZoom, self.outroViewProperties.width)
            }
            
            let isFirstPage = nextPageIndex == 0
            let isLastPage = nextPageIndex == lastPageIndex
            
            let spreadPageCount = isFirstPage || isLastPage || !isLandscape ? 1 : 2
            return (spreadPageCount, 4.0, 1.0)
        })
    }
    
    
    public func spreadOverlayView(verso: VersoView, overlaySize: CGSize, pageFrames: [Int : CGRect]) -> UIView? {
        
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
            hotspotOverlayView.tapGesture?.require(toFail: doubleTap)
        }
        
        return hotspotOverlayView
    }
    

    public func adjustPreloadPageIndexes(verso: VersoView, visiblePageIndexes: IndexSet, preloadPageIndexes:IndexSet) -> IndexSet? {
        
        guard let realOutroPageIndex = outroPageIndex, visiblePageIndexes.count > 0 else {
            return nil
        }
        
        // add outro to preload page indexes if we have scrolled close to it
        let distToOutro = realOutroPageIndex - visiblePageIndexes.last!
        if distToOutro < 10 {
            var adjustedPreloadPages = preloadPageIndexes
            adjustedPreloadPages.insert(realOutroPageIndex)
            return adjustedPreloadPages
        }
        else {
            return nil
        }
    }
}

    



// MARK: - VersoView Delegate

extension PagedPublicationView : VersoViewDelegate {
    
    public func currentPageIndexesChanged(verso:VersoView, pageIndexes:IndexSet, added:IndexSet, removed:IndexSet) {
        
//        print ("current pages changed: \(pageIndexes.arrayOfAllIndexes())")
        
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            
            // update the page number label's text and fade in, then out
            let newLabelText:String?
            
            if let outroIndex = self?.outroPageIndex, pageIndexes.contains(outroIndex) {
                newLabelText = nil
            }
            else {
                newLabelText = self!.dataSourceOptional.textForPageNumberLabel(pagedPublicationView: self!, pageIndexes: pageIndexes, pageCount: self!.pageCount)
            }
            
            self!.updatePageNumberLabel(withText: newLabelText)
            
        }
    }
    public func currentPageIndexesFinishedChanging(verso: VersoView, pageIndexes: IndexSet, added: IndexSet, removed: IndexSet) {
        
//        print ("current pages finished changing: \(pageIndexes.arrayOfAllIndexes())")

        // pages changed while we were zoomed in - trigger a zoom-out event
        if zoomedPageIndexes.count > 0 && pageIndexes != zoomedPageIndexes {
            _didZoomOut()
        }
        
        // find the oldPageIndexes, and trigger change event if it was a change
        let oldPageIndexes = pageIndexes.subtracting(added).union(removed)
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
        
    }

    public func visiblePageIndexesChanged(verso: VersoView, pageIndexes: IndexSet, added: IndexSet, removed: IndexSet) {
        
//        print ("visible pages changed: \(pageIndexes.arrayOfAllIndexes())")
    }
    
    
    public func didStartZoomingPages(verso: VersoView, zoomingPageIndexes: IndexSet, zoomScale: CGFloat) {
//        print ("did start zooming \(zoomScale) \(zoomingPageIndexes.arrayOfAllIndexes())")
    }
    
    public func didZoomPages(verso: VersoView, zoomingPageIndexes: IndexSet, zoomScale: CGFloat) {
//        print ("did zoom \(zoomScale) \(zoomingPageIndexes.arrayOfAllIndexes())")
    }
    
    public func didEndZoomingPages(verso: VersoView, zoomingPageIndexes: IndexSet, zoomScale: CGFloat) {
        
        if zoomScale > 1 {
            
            for pageIndex in zoomingPageIndexes {
                if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
                    , pageView.zoomImageLoadState == .notLoaded,
                    let zoomImageURL = pageViewModels?[sgn_safe:pageIndex]?.zoomImageURL {
                    
                    // started zooming on a page with no zoom-image loaded.
                    pageView.startLoadingZoomImageFromURL(zoomImageURL)
                    
                }
            }
        }
        
        // Handle a weird case where we think we are zoomed in, but what we are no zoomed into
        // is not what we have just zoomed into (eg. some page layout happened that we didnt respond to)
        // In this case trigger a zoom out event for existing zoomed-in pages, and reset the zoomed-in page indexes
        if zoomedPageIndexes != zoomingPageIndexes && zoomedPageIndexes.count > 0 {
            _didZoomOut()
        }
        
        
        // We are not zoomed in and we are being told that Verso has zoomed in.
        // Trigger a zoom-in event, and remember that we have done so.
        if zoomedPageIndexes.count == 0 && zoomingPageIndexes.count > 0 && zoomScale > 1 {
            _didZoomIn(zoomingPageIndexes)
        }
        // We are now zoomed out fully of the pages we were previously zoomed into.
        // Trigger zoom-out event, and remember that we are now not zoomed in.
        else if zoomedPageIndexes == zoomingPageIndexes && zoomScale <= 1 {
            // there were some zoomed in pages, but now we have zoomed out, so trigger zoom-out event
            _didZoomOut()
        }
    }
    
}




    

    
// MARK: - PagedPublicationPage delegate

extension PagedPublicationView : PagedPublicationPageViewDelegate {
    
    public func didFinishLoadingImage(pageView:PagedPublicationPageView, imageURL:URL, fromCache:Bool) {
        
        let pageIndex = pageView.pageIndex
        
        if activePageIndexesWithPendingLoadEvents.contains(pageIndex),
            let viewModel = pageViewModels?[sgn_safe:pageIndex] , viewModel.defaultImageURL == imageURL {
            
            // the page is active, and has not yet had its image loaded.
            // and the image url is the same as that of the viewModel at that page Index (view model hasnt changed since)
            // so trigger 'PAGE_LOADED' event
            // Only do this if the app is active - otherwise, when the app went into the background, we have sent a disappeared event
            if UIApplication.shared.applicationState == .active {
                triggerEvent_PageLoaded(pageIndex, fromCache: fromCache)
            }
            
            activePageIndexesWithPendingLoadEvents.remove(Int(pageIndex))
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
    
    func didTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        triggerEvent_PageTapped(pageIndex, location: locationInPage)
        
        delegate?.didTapPage(pagedPublicationView: self, pageIndex: pageIndex, locationInPage: locationInPage, hotspots: hotspots)
    }
    func didLongPressHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        triggerEvent_PageLongPressed(pageIndex, location: locationInPage)
                
        delegate?.didLongPressPage(pagedPublicationView: self, pageIndex: pageIndex, locationInPage: locationInPage, hotspots: hotspots)
    }
}








// Debug utilty for printing out indexSets
extension IndexSet {
    func arrayOfAllIndexes() -> [Int] {
        var allIndexes = [Int]()        
        self.forEach { (idx) in
            allIndexes.append(idx)
        }
        return allIndexes
    }
}



