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

@objc(SGNPagedPublicationLoaderProtocol)
public protocol PagedPublicationLoaderProtocol {
    
    /// the publication that is being loaded
    var publicationId:String { get }
    
    /// an optional background color that may be used before any data is loaded
    @objc optional var preloadedBackgroundColor:UIColor? { get }
    
    /// an optional page count (use 0 if unknown) to be used before data is loaded
    @objc optional var preloadedPageCount:Int { get }

    
    
    typealias PublicationLoadedHandler = ((PagedPublicationViewModelProtocol?, Error?)->Void)
    typealias PagesLoadedHandler = (([PagedPublicationPageViewModelProtocol]?, Error?)->Void)
    typealias HotspotsLoadedHandler = (([PagedPublicationHotspotViewModelProtocol]?, Error?)->Void)

    func load(publicationLoaded:@escaping PublicationLoadedHandler,
              pagesLoaded:@escaping PagesLoadedHandler,
              hotspotsLoaded:@escaping HotspotsLoadedHandler)
}



public protocol PagedPublicationViewDelegate : class {
    
    func pageIndexesChanged(current currentPageIndexes:IndexSet, previous oldPageIndexes:IndexSet, in pagedPublicationView:PagedPublicationView)
    func pageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView:PagedPublicationView)
    
    func didTap(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView)
    func didLongPress(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView)
    
    func didFinishLoadingPageImage(imageURL:URL, pageIndex:Int, in pagedPublicationView:PagedPublicationView)
    
    func outroDidAppear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView)
    func outroDidDisappear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView)
    
    func didLoad(publication publicationViewModel:PagedPublicationViewModelProtocol, in pagedPublicationView:PagedPublicationView)
    func didLoad(pages pageViewModels:[PagedPublicationPageViewModelProtocol], in pagedPublicationView:PagedPublicationView)
    func didLoad(hotspots hotspotViewModels:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView)
}


// default no-op
public extension PagedPublicationViewDelegate {
    func pageIndexesChanged(current currentPageIndexes:IndexSet, previous oldPageIndexes:IndexSet, in pagedPublicationView:PagedPublicationView) {}
    func pageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView:PagedPublicationView) {}
    
    func didTap(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView) {}
    func didLongPress(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView) {}
    
    func didFinishLoadingPageImage(imageURL:URL, pageIndex:Int, in pagedPublicationView:PagedPublicationView) {}
    
    func outroDidAppear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView) {}
    func outroDidDisappear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView) {}
    
    func didLoad(publication publicationViewModel:PagedPublicationViewModelProtocol, in pagedPublicationView:PagedPublicationView) {}
    func didLoad(pages pageViewModels:[PagedPublicationPageViewModelProtocol], in pagedPublicationView:PagedPublicationView) {}
    func didLoad(hotspots hotspotViewModels:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView) {}

}

public protocol PagedPublicationViewDataSource : PagedPublicationViewDataSourceOptional { }


public typealias OutroView = VersoPageView
public protocol PagedPublicationViewDataSourceOptional : class {
    
    func outroViewClass(pagedPublicationView:PagedPublicationView, size:CGSize) -> (OutroView.Type)?
    func configureOutroView(pagedPublicationView:PagedPublicationView, outroView:OutroView)
    func outroViewWidth(pagedPublicationView:PagedPublicationView, size:CGSize) -> CGFloat
    func outroViewMaxZoom(pagedPublicationView:PagedPublicationView, size:CGSize) -> CGFloat

    func textForPageNumberLabel(pagedPublicationView:PagedPublicationView, pageIndexes:IndexSet, pageCount:Int) -> String?
    
    func errorView(for error:Error?, in pagedPublicationView:PagedPublicationView) -> UIView?
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
    func errorView(for error:Error?, in pagedPublicationView:PagedPublicationView) -> UIView? {
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
        
        
        addSubview(loadingSpinnerView)
        
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
        
        loadingSpinnerView.center = verso.center
        
        layoutPageNumberLabel()
    }
    
    
    
    
    
    // MARK: - Public
    
    open weak var dataSource:PagedPublicationViewDataSource?
    
    open weak var delegate:PagedPublicationViewDelegate?
    
    
    /// The publication Id that is being or has been loaded. This is nil until loading begins.
    public fileprivate(set) var publicationId:String?
    
    /// The number of pages in the publication. This may be set before all the page images are loaded.
    public fileprivate(set) var pageCount:Int = 0
    
    
    
    /// The viewmodel of the publication, or nil if it hasnt been loaded yet
    public fileprivate(set) var publicationViewModel:PagedPublicationViewModelProtocol?
    
    /// The page view models for this publication, or nil if they havnt been loaded yet
    public fileprivate(set) var pageViewModels:[PagedPublicationPageViewModelProtocol]?
    
    /// The hotspot view models, keyed by their page index, or nil if not loaded yet
    public fileprivate(set) var hotspotsByPageIndex:[Int:[PagedPublicationHotspotViewModelProtocol]]?

    
    
    
    /// The page indexes of the spread that was centered when scrolling animations last ended
    public var currentPageIndexes:IndexSet {
        return verso.currentPageIndexes
    }
    
    /// The page indexes of all the pageViews that are currently visible
    public var visiblePageIndexes:IndexSet {
        return verso.visiblePageIndexes
    }
    
    /// The pan gesture used to change the pages
    public var panGestureRecognizer:UIPanGestureRecognizer {
        return verso.panGestureRecognizer
    }
    
    /// This will only return the outro view only after it has been configured.
    /// It is configured once the user has scrolled within a certain distance of the outro page (currently 10 pages).
    public var outroView:OutroView? {
        guard let outroIndex = outroPageIndex else {
            return nil
        }
        return verso.getPageViewIfLoaded(outroIndex)
    }
    
    /// Returns the pageview for the pageIndex, or nil if it hasnt been loaded yet
    public func getPageViewIfLoaded(_ pageIndex:Int) -> PagedPublicationPageView? {
        return verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
    }
    
    

    
    override open var backgroundColor: UIColor? {
        didSet {
            // update spinner color
            self.loadingSpinnerView.color = alternateColor
        }
    }
    public var alternateColor:UIColor {
        // get the alternate color for the bg color
        var whiteComponent:CGFloat = 1.0
        backgroundColor?.getWhite(&whiteComponent, alpha: nil)
        return (whiteComponent > 0.6) ? UIColor(white:0, alpha:0.7) : UIColor.white
    }
    
    
    // FIXME: move to Init?
    open func reload(publicationId:String, targetPageIndex:Int = 0) {
        
        // build a default graph loader
        let loader = PagedPublicationGraphLoader(publicationId:publicationId)
        
        reload(with:loader, targetPageIndex:targetPageIndex)
    }
    
    open func reload(with loader:PagedPublicationLoaderProtocol, targetPageIndex:Int = 0) {
        DispatchQueue.main.async { [weak self] in
            
            self?.publicationId = loader.publicationId
            
            
            // where to go to after configuration ends
            self?.postConfigureTargetPageIndex = targetPageIndex
            
            // reset model properties
            self?.publicationViewModel = nil
            self?.pageViewModels = nil
            self?.hotspotsByPageIndex = nil
            self?.hotspotOverlayView.isHidden = true
            self?.publicationAspectRatio = 0
            
            
            
            // this shows the loading spinner if we dont have a pagecount
            self?.configureBasics(backgroundColor: loader.preloadedBackgroundColor ?? nil,
                                  pageCount:  loader.preloadedPageCount ?? 0,
                                  targetPageIndex: targetPageIndex)
            
            
            // The callback when the basic publication details are loaded
            let publicationLoaded:PagedPublicationLoaderProtocol.PublicationLoadedHandler = { (loadedPublicationViewModel, error) in
                DispatchQueue.main.async { [weak self] in
                    guard let s = self else { return }
                    
                    if let pubVM = loadedPublicationViewModel {
                        
                        s.publicationViewModel = pubVM
                        
                        s.publicationAspectRatio = pubVM.aspectRatio
                        
                        // use the viewmodel to update the basics
                        s.configureBasics(backgroundColor: pubVM.bgColor,
                                              pageCount: pubVM.pageCount,
                                              targetPageIndex: s.postConfigureTargetPageIndex)
                        
                        s.delegate?.didLoad(publication: pubVM, in: s)
                    }
                    else {
                        s.configureError(with:error)
                    }
                }
            }
            
            // The callback when the pages are loaded
            let pagesLoaded:PagedPublicationLoaderProtocol.PagesLoadedHandler = { (loadedPageViewModels, error) in
                DispatchQueue.main.async { [weak self] in
                    guard let s = self else { return }

                    if let pageVMs = loadedPageViewModels {
                        s.configurePages(with: pageVMs,
                                             targetPageIndex: s.postConfigureTargetPageIndex)
                        
                        s.delegate?.didLoad(pages: pageVMs, in: s)
                    }
                    else {
                        s.configureError(with:error)
                    }
                }
            }
            // The callback when the hotspots are loaded
            let hotspotsLoaded:PagedPublicationLoaderProtocol.HotspotsLoadedHandler = { (loadedHotspotViewModels, error) in
                DispatchQueue.main.async { [weak self] in
                    guard let s = self else { return }

                    if let hotspotVMs = loadedHotspotViewModels {
                        s.configureHotspots(with: hotspotVMs)
                        
                        s.delegate?.didLoad(hotspots: hotspotVMs, in: s)
                    }
                }
            }
            
            // start the loader
            loader.load(publicationLoaded: publicationLoaded,
                        pagesLoaded: pagesLoaded,
                        hotspotsLoaded: hotspotsLoaded)
        }
    }
    
    
    
    public func jump(toPageIndex pageIndex:Int, animated:Bool) {
        
        // FIXME: if loading then save pageIndex for after load finished
        
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
    
    
    lazy fileprivate var verso:VersoView = {
        let verso = VersoView()
        verso.dataSource = self
        verso.delegate = self
        return verso
    }()
    
    
    
    
    
    // MARK: Loading and Configuring
    
    fileprivate var postConfigureTargetPageIndex:Int?
    
    fileprivate lazy var loadingSpinnerView:UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        view.color = UIColor(white:0, alpha:0.7)
        view.hidesWhenStopped = true
        return view
    }()
    
    
    /// The aspect ratio of all pages in the publication.
    /// This is only used when page model views are not yet loaded or contain no aspect ratio.
    fileprivate var publicationAspectRatio:CGFloat = 0
    
    
    
        // use the properties of the viewModel to reconfigure the view
    fileprivate func configureBasics(backgroundColor:UIColor?, pageCount:Int = 0, targetPageIndex:Int? = nil) {
        
        self.backgroundColor = backgroundColor
        self.pageCount = max(pageCount, 0)
        
        // show/hide spinner based on page count
        if pageCount > 0 {
            verso.alpha = 1.0
            loadingSpinnerView.stopAnimating()
        } else {
            // TODO: what if error?
            loadingSpinnerView.startAnimating()
            verso.alpha = 0.0
        }
        
        // force a re-fetch of the pageCount
        verso.reloadPages(targetPageIndex:targetPageIndex)
    }
    
    fileprivate func configurePages(with viewModels:[PagedPublicationPageViewModelProtocol], targetPageIndex:Int? = nil) {
        
        self.pageViewModels = viewModels
        
        let oldPageCount = pageCount
        pageCount = viewModels.count
        
        // hide overlay view if we have no pages
        self.hotspotOverlayView.isHidden = (pageCount == 0)
        
        
        // show/hide spinner based on page count
        if pageCount > 0 {
            verso.alpha = 1.0
            loadingSpinnerView.stopAnimating()
        }
        else {
            // TODO: what if error?
            loadingSpinnerView.startAnimating()
            verso.alpha = 0.0
        }
        
        
        if pageCount != oldPageCount {
            // force a re-fetch of the pageCount
            verso.reloadPages(targetPageIndex: targetPageIndex)
        }
        else {
            // just re-config the visible pages if pagecount didnt change
            verso.reconfigureVisiblePages()
        }
    }
    
    fileprivate func configureHotspots(with viewModels:[PagedPublicationHotspotViewModelProtocol]) {
        // configure hotspots in the background
        DispatchQueue.global().async {
            
            var newHotspotsByPageIndex:[Int:[PagedPublicationHotspotViewModelProtocol]] = [:]
            
            // split the hotspots by pageIndex
            for hotspotModel in viewModels {
                let hotspotPageIndexes = hotspotModel.getPageIndexes()
                
                for pageIndex in hotspotPageIndexes {
                    var hotspotsForPage = newHotspotsByPageIndex[pageIndex] ?? []
                    hotspotsForPage.append(hotspotModel)
                    newHotspotsByPageIndex[pageIndex] = hotspotsForPage
                }
            }
            
            // drop back to main for updating hotspots
            DispatchQueue.main.async { [weak self] in
                self?.hotspotsByPageIndex = newHotspotsByPageIndex
                
                self?.verso.reconfigureSpreadOverlay()
            }
        }
    }
    
    fileprivate func configureError(with error:Error?) {
        if let errorView = dataSource?.errorView(for: error, in: self) {
            
            insertSubview(errorView, belowSubview: verso)
            
            errorView.center = verso.center
            
            verso.alpha = 0.0
            loadingSpinnerView.stopAnimating()
        }
        else {
            // TODO: default error view
        }
    }
    

    
    
    
    
    // MARK: Page Number Label
    
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
    fileprivate func dimPageNumberLabel() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.beginFromCurrentState], animations: { 
            self.pageNumberLabel.alpha = 0.2
            }, completion: nil)
    }
    
    fileprivate func showPageNumberLabel() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(PagedPublicationView.dimPageNumberLabel), object: nil)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState], animations: {
            self.pageNumberLabel.alpha = 1.0
            }, completion: nil)
        
        self.perform(#selector(PagedPublicationView.dimPageNumberLabel), with: nil, afterDelay: 1.0)
    }
    
    fileprivate func updatePageNumberLabel(withText text:String?) {
        if text == nil {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(PagedPublicationView.dimPageNumberLabel), object: nil)

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
            backgroundColor?.getWhite(&whiteComponent, alpha: nil)
            
            // TODO: use cuttlefish?
            let bgIsDark = whiteComponent > 0.6 ? false : true
            
            if let viewModel = pageViewModels?[sgn_safe:Int(pageIndex)] {
                
                // valid view model
                pubPage.configure(viewModel, publicationAspectRatio:publicationAspectRatio, darkBG:bgIsDark)
            }                
            else
            {
                // build blank view model
                let viewModel = PagedPublicationPageViewModel(pageIndex:pageIndex, pageTitle:String(pageIndex+1))
                
                pubPage.configure(viewModel, publicationAspectRatio:publicationAspectRatio, darkBG:bgIsDark)
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
        guard (outroPageIndex != nil && pageFrames[outroPageIndex!] != nil) == false else {
            return nil
        }
        
        // no hotspots to show
        guard hotspotsByPageIndex != nil else {
            return nil
        }
        
        // get the hotspots for this spread - dont add hotspots more than once
        var spreadHotspots:[PagedPublicationHotspotViewModelProtocol] = []
        for (pageIndex, _) in pageFrames {
            if let hotspots = hotspotsByPageIndex![pageIndex] {
                for hotspot in hotspots {                    
                    if spreadHotspots.contains(where:{ $0 === hotspot }) == false {
                        spreadHotspots.append(hotspot)
                    }
                }
            }
        }
        if spreadHotspots.count == 0 {
            return nil
        }
        
        // configure the overlay
        hotspotOverlayView.isHidden = (self.pageViewModels?.count ?? 0) == 0
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
        // TODO: use datasource to define this value
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
        
        let oldPageIndexes = pageIndexes.subtracting(added).union(removed)

        delegate?.pageIndexesChanged(current: pageIndexes, previous: oldPageIndexes, in: self)
        
        if let outroIndex = outroPageIndex, let outroView = verso.getPageViewIfLoaded(outroIndex) {
            if added.contains(outroIndex) {
                delegate?.outroDidAppear(outroView, in: self)
            } else if removed.contains(outroIndex) {
                delegate?.outroDidDisappear(outroView, in: self)
            }
        }
    }
    public func currentPageIndexesFinishedChanging(verso: VersoView, pageIndexes: IndexSet, added: IndexSet, removed: IndexSet) {

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
        
        delegate?.pageIndexesFinishedChanging(current: pageIndexes, previous: oldPageIndexes, in: self)
    }

    public func visiblePageIndexesChanged(verso: VersoView, pageIndexes: IndexSet, added: IndexSet, removed: IndexSet) {
        
    }
    
    
    public func didStartZoomingPages(verso: VersoView, zoomingPageIndexes: IndexSet, zoomScale: CGFloat) {
    }
    
    public func didZoomPages(verso: VersoView, zoomingPageIndexes: IndexSet, zoomScale: CGFloat) {
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
    
    public func didFinishLoadingImage(_ pageView:PagedPublicationPageView, imageURL:URL, fromCache:Bool) {
        
        let pageIndex = pageView.pageIndex
        
        if activePageIndexesWithPendingLoadEvents.contains(pageIndex),
            let viewModel = pageViewModels?[sgn_safe:pageIndex] , viewModel.viewImageURL == imageURL {
            
            // the page is active, and has not yet had its image loaded.
            // and the image url is the same as that of the viewModel at that page Index (view model hasnt changed since)
            // so trigger 'PAGE_LOADED' event
            // Only do this if the app is active - otherwise, when the app went into the background, we have sent a disappeared event
            if UIApplication.shared.applicationState == .active {
                triggerEvent_PageLoaded(pageIndex, fromCache: fromCache)
            }
            
            activePageIndexesWithPendingLoadEvents.remove(Int(pageIndex))
        }
        
        delegate?.didFinishLoadingPageImage(imageURL: imageURL, pageIndex: pageIndex, in: self)
    }
//    public func didFinishLoadingZoomImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool) {
//    
//    }
    
//    public func didConfigure(pageView:PagedPublicationPageView, viewModel:PagedPublicationPageViewModel) {
//
//    }
}




extension PagedPublicationView : HotspotOverlayViewDelegate {
    
    func didTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        triggerEvent_PageTapped(pageIndex, location: locationInPage)
        
        delegate?.didTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    func didLongPressHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        triggerEvent_PageLongPressed(pageIndex, location: locationInPage)
        
        delegate?.didLongPress(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
}

