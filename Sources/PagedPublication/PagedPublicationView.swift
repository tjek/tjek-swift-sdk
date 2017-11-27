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
    
    /// where the loader loads it's data from (eg. 'legacy' or 'graph')
    var sourceType:String { get }
    
    /// An optional view model that is used to configure the publication before any loading begins
    var preloadedPublication:PagedPublicationViewModelProtocol? { get }

    typealias PublicationLoadedHandler = ((PagedPublicationViewModelProtocol?, Error?) -> Void)
    typealias PagesLoadedHandler = (([PagedPublicationPageViewModelProtocol]?, Error?) -> Void)
    typealias HotspotsLoadedHandler = (([PagedPublicationHotspotViewModelProtocol]?, Error?) -> Void)

    func load(publicationLoaded:@escaping PublicationLoadedHandler,
              pagesLoaded:@escaping PagesLoadedHandler,
              hotspotsLoaded:@escaping HotspotsLoadedHandler)
}



public protocol PagedPublicationViewDelegate : class {
    
    func pageIndexesChanged(current currentPageIndexes:IndexSet, previous oldPageIndexes:IndexSet, in pagedPublicationView:PagedPublicationView)
    func pageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView:PagedPublicationView)
    
    func didTap(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView)
    func didLongPress(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView)
    func didDoubleTap(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView)
    
    func didFinishLoadingPageImage(imageURL:URL, pageIndex:Int, in pagedPublicationView:PagedPublicationView)
    
    func outroDidAppear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView)
    func outroDidDisappear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView)
    
    func didStartReloading(in pagedPublicationView:PagedPublicationView)
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
    func didDoubleTap(pageIndex:Int, locationInPage:CGPoint, hittingHotspots:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView) {}

    func didFinishLoadingPageImage(imageURL:URL, pageIndex:Int, in pagedPublicationView:PagedPublicationView) {}
    
    func outroDidAppear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView) {}
    func outroDidDisappear(_ outroView:OutroView, in pagedPublicationView:PagedPublicationView) {}
    
    func didStartReloading(in pagedPublicationView:PagedPublicationView) {}
    func didLoad(publication publicationViewModel:PagedPublicationViewModelProtocol, in pagedPublicationView:PagedPublicationView) {}
    func didLoad(pages pageViewModels:[PagedPublicationPageViewModelProtocol], in pagedPublicationView:PagedPublicationView) {}
    func didLoad(hotspots hotspotViewModels:[PagedPublicationHotspotViewModelProtocol], in pagedPublicationView:PagedPublicationView) {}
}

public protocol PagedPublicationViewDataSource : PagedPublicationViewDataSourceOptional { }


public typealias OutroView = VersoPageView
public protocol PagedPublicationViewDataSourceOptional : class {
    
    func configure(outroView:OutroView, for pagedPublicationView:PagedPublicationView)
    func outroViewClass(for pagedPublicationView:PagedPublicationView) -> (OutroView.Type)?
    func outroViewWidth(for pagedPublicationView:PagedPublicationView) -> CGFloat
    func outroViewMaxZoom(for pagedPublicationView:PagedPublicationView) -> CGFloat


    func textForPageNumberLabel(pageIndexes:IndexSet, pageCount:Int, for pagedPublicationView:PagedPublicationView) -> String?
    
    func errorView(with error:Error?, for pagedPublicationView:PagedPublicationView) -> UIView?
}

// Default values for datasource
public extension PagedPublicationViewDataSourceOptional {
    func configure(outroView:OutroView, for pagedPublicationView:PagedPublicationView) { }
    func outroViewClass(for pagedPublicationView:PagedPublicationView) -> (OutroView.Type)? {
        return nil
    }
    func outroViewWidth(for pagedPublicationView:PagedPublicationView) -> CGFloat {
        return 0.9
    }
    func outroViewMaxZoom(for pagedPublicationView:PagedPublicationView) -> CGFloat {
        return 1.0
    }
    
    func textForPageNumberLabel(pageIndexes:IndexSet, pageCount:Int, for pagedPublicationView:PagedPublicationView) -> String? {
        if pageIndexes.count == 1 {
            return "\(pageIndexes.first!+1) / \(pageCount)"
        }
        else if pageIndexes.count > 1 {
            return "\(pageIndexes.first!+1)-\(pageIndexes.last!+1) / \(pageCount)"
        }
        return nil
    }
    
    func errorView(with error:Error?, for pagedPublicationView:PagedPublicationView) -> UIView? {
        return nil
    }
}
/// Have PagedPublicationView as the source of the default optional values, for when dataSource is nil.
extension PagedPublicationView : PagedPublicationViewDataSourceOptional {}



@objc(SGNPagedPublicationView)
open class PagedPublicationView : UIView {

    public override init(frame: CGRect) {
        super.init(frame:frame)
        
        
        addSubview(loadingSpinnerView)
        addSubview(errorViewContainer)
        
        verso.frame = frame
        verso.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(verso)
        
        addSubview(pageNumberLabel)
        pageNumberLabel.alpha = 0
        
        addSubview(progressBarView)
        progressBarView.alpha = 0
        
        backgroundColor = UIColor.white
    }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        verso.frame = bounds
        
        loadingSpinnerView.center = verso.center
        errorViewContainer.frame = bounds
        
        layoutPageNumberLabel()
        updateProgressBar()
    }
    
    
    
    
    
    // MARK: - Public
    
    open weak var dataSource:PagedPublicationViewDataSource?
    
    open weak var delegate:PagedPublicationViewDelegate?
    
    
    /// The publication Id that is being or has been loaded. This is nil until loading begins.
    public fileprivate(set) var publicationId:String?
    
    /// The number of pages in the publication. This may be set before all the page images are loaded.
    public fileprivate(set) var pageCount:Int = 0
    
    /// The aspect ratio of all pages in the publication.
    /// This is only used when page model views are not yet loaded or contain no aspect ratio.
    public fileprivate(set) var publicationAspectRatio:CGFloat = 0
    
    
    
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
    public var isOutroVisible:Bool {
        return outroPageIndex != nil && visiblePageIndexes.contains(outroPageIndex!)
    }
    
    
    /// Returns the pageview for the pageIndex, or nil if it hasnt been loaded yet
    public func getPageViewIfLoaded(_ pageIndex:Int) -> PagedPublicationPageView? {
        return verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
    }
    
    

    
    override open var backgroundColor: UIColor? {
        didSet {
            let alternate = alternateColor
            // update spinner color
            self.loadingSpinnerView.color = alternate
            
            
            var whiteComponent:CGFloat = 1.0
            backgroundColor?.getWhite(&whiteComponent, alpha: nil)
        
            self.progressBarView.backgroundColor = whiteComponent <= 0.05 ? UIColor(white:0.58, alpha:0.3) : UIColor(white:0, alpha:0.3)
        }
    }
    public var alternateColor:UIColor {
        // get the alternate color for the bg color
        var whiteComponent:CGFloat = 1.0
        backgroundColor?.getWhite(&whiteComponent, alpha: nil)
        return (whiteComponent > 0.6) ? UIColor(white:0, alpha:0.7) : UIColor.white
    }
    
    
    fileprivate var reloadId:Int = 0
    
    open func reload(with loader:PagedPublicationLoaderProtocol, jumpTo pageIndex:Int = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            
            // keep track of current reload, so that we can ignore callbacks if there has been a future reload
            s.reloadId += 1
            let activeReloadId = s.reloadId
            
            let loadingPublicationId = loader.publicationId
            
            s.publicationId = loadingPublicationId
            
            // where to go to after configuration ends
            s.postReloadPageIndex = pageIndex
            
            // reset model properties
            s.publicationViewModel = nil
            s.pageViewModels = nil
            s.hotspotsByPageIndex = nil
            s.hotspotOverlayView.isHidden = true
            
            s.clearErrorView()
            
            // this shows the loading spinner if we dont have a pagecount
            s.configureBasics(backgroundColor: loader.preloadedPublication?.bgColor ?? nil,
                              pageCount:  loader.preloadedPublication?.pageCount ?? 0,
                              aspectRatio: loader.preloadedPublication?.aspectRatio ?? 0,
                              jumpTo: pageIndex)

            
            s.delegate?.didStartReloading(in:s)
            
            // The callback when the basic publication details are loaded
            let publicationLoaded:PagedPublicationLoaderProtocol.PublicationLoadedHandler = { (loadedPublicationViewModel, error) in
                DispatchQueue.main.async { [weak self] in
                    guard let s = self else { return }
                    
                    // make sure we havnt reloaded since this started
                    guard s.reloadId == activeReloadId else {
                        return
                    }

                    // dont update publication even if it loaded successfully if we got an error loading the pages
                    guard s.showingError == false else {
                        return
                    }
                    
                    if let pubVM = loadedPublicationViewModel {
                        
                        // successful reload, event handler can now call opened & didAppear
                        if s.lifecycleEventHandler == nil || s.lifecycleEventHandler!.publicationId.id != pubVM.publicationId || s.lifecycleEventHandler!.publicationId.source != loader.sourceType {
                            s.lifecycleEventHandler = PagedPublicationLifecycleEventHandler(publicationId:IdField(pubVM.publicationId, source:loader.sourceType)!, ownerId: IdField(pubVM.ownerId, source:loader.sourceType)!)
                            s.lifecycleEventHandler?.opened()
                            s.lifecycleEventHandler?.didAppear()
                        }
                        

                        s.publicationViewModel = pubVM
                        
                        // use the viewmodel to update the basics
                        s.configureBasics(backgroundColor: pubVM.bgColor,
                                          pageCount: pubVM.pageCount,
                                          aspectRatio: pubVM.aspectRatio,
                                          jumpTo: s.postReloadPageIndex)
                        
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
                    
                    // make sure we havnt reloaded since this started
                    guard s.reloadId == activeReloadId else {
                        return
                    }
                    
                    // dont show pages even if they are loaded successfully if we got an error loading the publication
                    guard s.showingError == false else {
                        return
                    }
                    
                    if let pageVMs = loadedPageViewModels {
                        s.configurePages(with: pageVMs,
                                         targetPageIndex: s.postReloadPageIndex)
                        
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
                    
                    // make sure we havnt reloaded since this started
                    guard s.reloadId == activeReloadId else {
                        return
                    }
                    
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
    
    
    
    /// Tell the page publication that it is now visible again.
    /// (eg. when a view that was placed over the top of this view is removed, and the content becomes visible again).
    /// This will restart event collection. You MUST remember to call this if you previously called `didEnterBackground`, otherwise
    /// the PagePublicationView will not function correctly.
    public func didEnterForeground() {
        
        // start listening for the app going into the background
        NotificationCenter.default.addObserver(self, selector: #selector(PagedPublicationView._willResignActiveNotification(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        
        lifecycleEventHandler?.didAppear()
    }
    
    /// Tell the page publication that it is no longer visible.
    /// (eg. a view has been placed over the top of the PagedPublicationView, so the content is no longer visible)
    /// This will pause event collection, until `didEnterForeground` is called again.
    public func didEnterBackground() {
        
        // stop listening for going into the background
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        
        lifecycleEventHandler?.didDisappear()
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
    
    fileprivate lazy var outroOutsideTapGesture:UITapGestureRecognizer = { [weak self] in
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapOutsideOutro(_:)))
        tap.cancelsTouchesInView = false
        
        self?.addGestureRecognizer(tap)
        return tap
    }()
    
    @objc
    func didTapOutsideOutro(_ tap:UITapGestureRecognizer) {
        guard let outroView = self.outroView, currentPageIndexes.contains(outroView.pageIndex) else {
            return
        }
        
        
        let location = tap.location(in: outroView)
        if outroView.bounds.contains(location) == false {
            jump(toPageIndex: pageCount-1, animated: true)
        }
    }
    
    
    
    fileprivate var lifecycleEventHandler:PagedPublicationLifecycleEventHandler?
    
    
    lazy fileprivate var verso:VersoView = {
        let verso = VersoView()
        verso.dataSource = self
        verso.delegate = self
        return verso
    }()
    
    
    fileprivate lazy var loadingSpinnerView:UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        view.color = UIColor(white:0, alpha:0.7)
        view.hidesWhenStopped = true
        return view
    }()
    

    
    
    
    // MARK: Loading and Configuring
    
    /// If we are in the process of reloading a publication this may be non-nil
    public fileprivate(set) var postReloadPageIndex:Int?
    
    
        // use the properties of the viewModel to reconfigure the view
    fileprivate func configureBasics(backgroundColor:UIColor?, pageCount:Int = 0, aspectRatio:CGFloat = 0, jumpTo pageIndex:Int? = nil) {
        
        self.backgroundColor = backgroundColor
        self.pageCount = max(pageCount, 0)
        self.publicationAspectRatio = aspectRatio
        
        // show/hide spinner based on page count
        if pageCount > 0 {
            verso.alpha = 1.0
            loadingSpinnerView.stopAnimating()
        } else {
            loadingSpinnerView.startAnimating()
            verso.alpha = 0.0
        }
        
        // force a re-fetch of the pageCount
        verso.reloadPages(targetPageIndex:pageIndex)
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
    
    
    
    // MARK: Error handling
    
    fileprivate lazy var errorViewContainer = UIView()
    
    /// Whether we are showing an error
    fileprivate var showingError:Bool = false
    
    fileprivate func configureError(with error:Error?) {
        
        guard showingError == false else {
            return
        }
        
        // clear out any old error views
        for preSubview in errorViewContainer.subviews {
            preSubview.removeFromSuperview()
        }
        
        if let errorView = dataSource?.errorView(with: error, for: self) {
            
            showingError = true
            
            // add the new error view
            errorViewContainer.addSubview(errorView)
            
            // Constrain and center the errorView within the errorViewContainer
            errorView.translatesAutoresizingMaskIntoConstraints = false
            
            let leftCnst = NSLayoutConstraint(item:errorView, attribute:.left, relatedBy:.greaterThanOrEqual, toItem:errorViewContainer, attribute:.leftMargin, multiplier:1, constant:0)
            leftCnst.priority = UILayoutPriorityRequired
            
            let rightCnst = NSLayoutConstraint(item:errorView, attribute:.right, relatedBy:.lessThanOrEqual, toItem:errorViewContainer, attribute:.rightMargin, multiplier:1, constant:0)
            rightCnst.priority = UILayoutPriorityRequired
            
            let topCnst = NSLayoutConstraint(item:errorView, attribute:.top, relatedBy:.greaterThanOrEqual, toItem:errorViewContainer, attribute:.topMargin, multiplier:1, constant:0)
            topCnst.priority = UILayoutPriorityRequired
            
            let bottomCnst = NSLayoutConstraint(item:errorView, attribute:.bottom, relatedBy:.lessThanOrEqual, toItem:errorViewContainer, attribute:.bottomMargin, multiplier:1, constant:0)
            bottomCnst.priority = UILayoutPriorityRequired
            
            let centerXCnst = NSLayoutConstraint(item:errorView, attribute:.centerX, relatedBy:.equal, toItem:errorViewContainer, attribute:.centerXWithinMargins, multiplier:1, constant:0)
            let centerYCnst = NSLayoutConstraint(item:errorView, attribute:.centerY, relatedBy:.equal, toItem:errorViewContainer, attribute:.centerYWithinMargins, multiplier:1, constant:0)
            
            NSLayoutConstraint.activate([leftCnst, rightCnst, topCnst, bottomCnst, centerXCnst, centerYCnst])
            
            // show the error container
            UIView.animate(withDuration:0.2) {
                // show error and hide spinner/verso
                self.errorViewContainer.alpha = 1.0
                self.verso.alpha = 0.0
                self.pageNumberLabel.isHidden = true
                self.loadingSpinnerView.stopAnimating()
            }
        }
        else {
            // TODO: default error view
        }
    }
    
    fileprivate func clearErrorView() {
        
        showingError = false
        
        UIView.animate(withDuration:0.2) {
            // show error and hide spinner/verso
            self.errorViewContainer.alpha = 0.0
            self.verso.alpha = 1.0
            self.pageNumberLabel.isHidden = false
        }
    }
    

    
    
    
    
    // MARK: Progress bar
    
    fileprivate lazy var progressBarView:UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        return view
    }()

    
    
    fileprivate func updateProgressBar() {
        
        let lastPageIndex = CGFloat(self.visiblePageIndexes.last ?? 0)
        let pageCount = CGFloat(self.pageCount-1)
        
        let progress = min(1, max(0, pageCount > 0 ? lastPageIndex / pageCount : 0))
        
        let height:CGFloat = 4
        let width:CGFloat = bounds.width * progress
        var frame = CGRect(x:bounds.minX,
                           y:bounds.maxY - height,
                           width: progressBarView.frame.width,
                           height:height)
        
        progressBarView.frame = frame
        frame.size.width = width
        
        UIView.animate(withDuration: 0.3, delay:0, options: [], animations: { [weak self] in
            self?.progressBarView.frame = frame
        })

        
        if isOutroVisible {
            UIView.animate(withDuration: 0.1, delay:0, options: [], animations: { [weak self] in
                self?.progressBarView.alpha = 0
            })
        } else {
            showProgressBarView()
        }
    }
    
    @objc
    fileprivate func dimProgressBarView() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.beginFromCurrentState], animations: {
            self.progressBarView.alpha = 0.5
        }, completion: nil)
    }
    
    fileprivate func showProgressBarView() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(PagedPublicationView.dimProgressBarView), object: nil)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState], animations: {
            self.progressBarView.alpha = 1.0
        }, completion: nil)
        
        self.perform(#selector(PagedPublicationView.dimProgressBarView), with: nil, afterDelay: 1.0)
    }
    
    
    
    
    // MARK: Page Number Label
    
    fileprivate var pageNumberLabel:PageNumberLabel = PageNumberLabel()
    
    class PageNumberLabel : UILabel {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            layer.cornerRadius = 6
            layer.masksToBounds = true
            textColor = UIColor.white
            
            layer.backgroundColor = UIColor(white: 0, alpha: 0.3).cgColor
            textAlignment = .center
            
            // monospaced numbers
            let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle.headline)
            let monospacedNumbersFontDescriptor = fontDescriptor.addingAttributes(
                [
                    UIFontDescriptorFeatureSettingsAttribute: [
                        [
                            UIFontFeatureTypeIdentifierKey: kNumberSpacingType,
                            UIFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector
                        ],
                        [
                            UIFontFeatureTypeIdentifierKey: kStylisticAlternativesType,
                            UIFontFeatureSelectorIdentifierKey: kStylisticAltOneOnSelector
                        ],
                        [
                            UIFontFeatureTypeIdentifierKey: kStylisticAlternativesType,
                            UIFontFeatureSelectorIdentifierKey: kStylisticAltTwoOnSelector
                        ]
                    ]
                ])
            //TODO: dynamic font size
            font = UIFont(descriptor: monospacedNumbersFontDescriptor, size: 16)
            
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
        
        lblFrame.size.width =  ceil(lblFrame.size.width)
        lblFrame.size.height = round(lblFrame.size.height)
        
        lblFrame.origin.x = round(bounds.midX - (lblFrame.width / 2))
        
        if UIDevice().userInterfaceIdiom == .phone {
            switch UIScreen.main.nativeBounds.height {
            case 2436: // iPhoneX
                lblFrame.origin.y = round(bounds.maxY - 22 - lblFrame.height)
            default:
                lblFrame.origin.y = round(bounds.maxY - 11 - lblFrame.height)
            }
        }
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
    
    var currPageLabelText:String?
    
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
            } else if currPageLabelText != text {
                UIView.transition(with: pageNumberLabel, duration: 0.15, options: [.transitionCrossDissolve, .beginFromCurrentState], animations: {
                    self.pageNumberLabel.text = text
                    self.layoutPageNumberLabel()
                })
            }
            
            showPageNumberLabel()
        }
        currPageLabelText = text
    }
    
    
    
    
    
    /// the view that is placed over the current spread
    fileprivate var hotspotOverlayView:HotspotOverlayView = HotspotOverlayView()
    
    
    
    
    // MARK: Page Appearance/Disappearance
    
    @objc
    fileprivate func _willResignActiveNotification(_ notification:Notification) {
        
        // once in the background, listen for coming back to the foreground again
        NotificationCenter.default.addObserver(self, selector: #selector(PagedPublicationView._didBecomeActiveNotification(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        didEnterBackground()
    }
    @objc
    fileprivate func _didBecomeActiveNotification(_ notification:Notification) {
        
        // once in the foreground, stop listen for that again
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        didEnterForeground()
    }
}








// MARK: - VersoView DataSource

extension PagedPublicationView : VersoViewDataSource {

    public func configure(pageView:VersoPageView, for verso:VersoView) {
        
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
            dataSourceOptional.configure(outroView:pageView, for:self)
        }
    }
    
    public func pageViewClass(on pageIndex:Int, for verso:VersoView) -> VersoPageViewClass {
        if outroPageIndex == pageIndex {
            return outroViewProperties.viewClass ?? VersoPageView.self
        }
        else {
            return PagedPublicationPageView.self
        }
    }
    
    public func spreadConfiguration(with size:CGSize, for verso:VersoView) -> VersoSpreadConfiguration {
        
        // update outro properties from datasource
        outroViewProperties = (dataSourceOptional.outroViewClass(for:self),
                               dataSourceOptional.outroViewWidth(for:self),
                               dataSourceOptional.outroViewMaxZoom(for:self))
        
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
    
    
    public func spreadOverlayView(overlaySize:CGSize, pageFrames:[Int:CGRect], for verso:VersoView) -> UIView? {
        
        // no overlay for outro
        guard (outroPageIndex != nil && pageFrames[outroPageIndex!] != nil) == false else {
            return nil
        }
        
        
        // get the hotspots for this spread - dont add hotspots more than once
        var spreadHotspots:[PagedPublicationHotspotViewModelProtocol] = []
        
        if hotspotsByPageIndex != nil {
            for (pageIndex, _) in pageFrames {
                if let hotspots = hotspotsByPageIndex![pageIndex] {
                    for hotspot in hotspots {
                        if spreadHotspots.contains(where:{ $0 === hotspot }) == false {
                            spreadHotspots.append(hotspot)
                        }
                    }
                }
            }
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
    

    public func adjustPreloadPageIndexes(_ preloadPageIndexes:IndexSet, visiblePageIndexes:IndexSet, for verso:VersoView) -> IndexSet? {
        
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
    
    public func currentPageIndexesChanged(current currentPageIndexes:IndexSet, previous oldPageIndexes:IndexSet, in verso:VersoView) {
        
        // this is a bit of a hack to cancel the touch-gesture when we start scrolling
        self.hotspotOverlayView.touchGesture?.isEnabled = false
        self.hotspotOverlayView.touchGesture?.isEnabled = true
        
        lifecycleEventHandler?.clearSpreadEventHandler()
        
        
        // remove the outro index when refering to page indexes outside of PagedPub
        var currentExOutro = currentPageIndexes
        var oldExOutro = oldPageIndexes
        if let outroIndex = self.outroPageIndex {
            currentExOutro.remove(outroIndex)
            oldExOutro.remove(outroIndex)
        }
        delegate?.pageIndexesChanged(current: currentExOutro, previous: oldExOutro, in: self)
        
        
        // check if the outro has newly appeared or disappeared (not if it's in both old & current)
        if let outroIndex = outroPageIndex, let outroView = verso.getPageViewIfLoaded(outroIndex) {
            
            let addedIndexes = currentPageIndexes.subtracting(oldPageIndexes)
            let removedIndexes = oldPageIndexes.subtracting(currentPageIndexes)
            
            if addedIndexes.contains(outroIndex) {
                delegate?.outroDidAppear(outroView, in: self)
                outroOutsideTapGesture.isEnabled = true
            } else if removedIndexes.contains(outroIndex) {
                delegate?.outroDidDisappear(outroView, in: self)
                outroOutsideTapGesture.isEnabled = false
            }
        }
        
        
        
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            
            // update the page number label's text and fade in, then out
            let newLabelText:String?
            
            if let outroIndex = s.outroPageIndex, currentPageIndexes.contains(outroIndex) {
                newLabelText = nil
            }
            else {
                newLabelText = s.dataSourceOptional.textForPageNumberLabel(pageIndexes: currentPageIndexes, pageCount: s.pageCount, for:s)
            }
            
            s.updatePageNumberLabel(withText: newLabelText)
            
            s.updateProgressBar()
        }
    }
    
    public func currentPageIndexesFinishedChanging(current currentPageIndexes:IndexSet, previous oldPageIndexes:IndexSet, in verso:VersoView) {

        
        // make a new spreadEventHandler (unless it's the outro)
        if (outroPageIndex == nil || currentPageIndexes.contains(outroPageIndex!) == false) {
            
            lifecycleEventHandler?.newSpreadEventHandler(for: currentPageIndexes)
            
            for pageIndex in currentPageIndexes {
                if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView, pageView.imageLoadState == .loaded {
                    lifecycleEventHandler?.spreadEventHandler?.pageLoaded(pageIndex: pageIndex)
                }
            }
            
            if verso.zoomScale > 1 {
                lifecycleEventHandler?.spreadEventHandler?.didZoomIn()
            }
        }

        
        // remove the outro index when refering to page indexes outside of PagedPub
        var currentExOutro = currentPageIndexes
        var oldExOutro = oldPageIndexes
        if let outroIndex = self.outroPageIndex {
            currentExOutro.remove(outroIndex)
            oldExOutro.remove(outroIndex)
        }
        delegate?.pageIndexesFinishedChanging(current: currentExOutro, previous: oldExOutro, in: self)
        
        
        
        // cancel the loading of the zoomimage after a page disappears
        let removedIndexes = oldPageIndexes.subtracting(currentPageIndexes)
        for pageIndex in removedIndexes {
            if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView {
                pageView.clearZoomImage(animated: false)
            }
        }
    }

//    public func visiblePageIndexesChanged(current currentPageIndexes:IndexSet, previous oldPageIndexes:IndexSet, in verso:VersoView) {
//        
//    }
//    public func didStartZooming(pages pageIndexes:IndexSet, zoomScale:CGFloat, in verso:VersoView) {
//        
//    }
//    public func didZoom(pages pageIndexes:IndexSet, zoomScale:CGFloat, in verso:VersoView) {
//        
//    }
    
    public func didEndZooming(pages pageIndexes:IndexSet, zoomScale:CGFloat, in verso:VersoView) {
        
        if zoomScale > 1 {
            for pageIndex in pageIndexes {
                if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
                    , pageView.zoomImageLoadState == .notLoaded,
                    let zoomImageURL = pageViewModels?[sgn_safe:pageIndex]?.zoomImageURL {
                    
                    // started zooming on a page with no zoom-image loaded.
                    pageView.startLoadingZoomImageFromURL(zoomImageURL)
                    
                }
            }
            
            lifecycleEventHandler?.spreadEventHandler?.didZoomIn()
        }
        else {
            lifecycleEventHandler?.spreadEventHandler?.didZoomOut()
        }
    }
    
}




    

    
// MARK: - PagedPublicationPage delegate

extension PagedPublicationView : PagedPublicationPageViewDelegate {
//    public func didConfigure(pageView: PagedPublicationPageView, with viewModel: PagedPublicationPageViewModelProtocol) {
//        
//    }
    
    public func didFinishLoading(viewImage imageURL:URL, fromCache:Bool, in pageView:PagedPublicationPageView) {
        let pageIndex = pageView.pageIndex
        
        // tell the spread that the image loaded. 
        // Will be ignored if page isnt part of the spread
        lifecycleEventHandler?.spreadEventHandler?.pageLoaded(pageIndex: pageIndex)

        
        delegate?.didFinishLoadingPageImage(imageURL: imageURL, pageIndex: pageIndex, in: self)
    }
    
//    public func didFinishLoading(zoomImage imageURL:URL, fromCache:Bool, in pageView:PagedPublicationPageView) {
//        
//    }
}




// MARK: - Hotspot Overlay delegate

extension PagedPublicationView : HotspotOverlayViewDelegate {
    
    func didTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotRects:[CGRect], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        lifecycleEventHandler?.spreadEventHandler?.pageTapped(pageIndex: pageIndex, location: locationInPage, hittingHotspots: (hotspots.count > 0))
        
        delegate?.didTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    func didLongPressHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotRects:[CGRect], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        lifecycleEventHandler?.spreadEventHandler?.pageLongPressed(pageIndex: pageIndex, location: locationInPage)
        
        delegate?.didLongPress(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    
    func didDoubleTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotRects:[CGRect], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {
        
        lifecycleEventHandler?.spreadEventHandler?.pageDoubleTapped(pageIndex: pageIndex, location: locationInPage)
        
        delegate?.didDoubleTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
}

