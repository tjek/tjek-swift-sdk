//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import Verso

/// The object that does the fetching of the publication's
public protocol PagedPublicationViewDataLoader {
    typealias PublicationLoadedHandler = ((Result<PagedPublicationView.PublicationModel>) -> Void)
    typealias PagesLoadedHandler = ((Result<[PagedPublicationView.PageModel]>) -> Void)
    typealias HotspotsLoadedHandler = ((Result<[PagedPublicationView.HotspotModel]>) -> Void)

    func startLoading(publicationId: PagedPublicationView.PublicationId, publicationLoaded: @escaping PublicationLoadedHandler, pagesLoaded: @escaping PagesLoadedHandler, hotspotsLoaded: @escaping HotspotsLoadedHandler)
    func cancelLoading()
}

public typealias OutroView = VersoPageView
public typealias OutroViewProperties = (viewClass: OutroView.Type, width: CGFloat, maxZoom: CGFloat)

public protocol PagedPublicationViewDelegate: class {
    // MARK: Page Change events
    func pageIndexesChanged(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView)
    func pageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView)
    func didFinishLoadingPageImage(imageURL: URL, pageIndex: Int, in pagedPublicationView: PagedPublicationView)
    
    // MARK: Hotspot events
    func didTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
    func didLongPress(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
    func didDoubleTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
    
    // MARK: Outro events
    func outroDidAppear(_ outroView: OutroView, in pagedPublicationView: PagedPublicationView)
    func outroDidDisappear(_ outroView: OutroView, in pagedPublicationView: PagedPublicationView)
    
    // MARK: Loading events
    func didStartReloading(in pagedPublicationView: PagedPublicationView)
    func didLoad(publication publicationModel: PagedPublicationView.PublicationModel, in pagedPublicationView: PagedPublicationView)
    func didLoad(pages pageModels: [PagedPublicationView.PageModel], in pagedPublicationView: PagedPublicationView)
    func didLoad(hotspots hotspotModels: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
}

public protocol PagedPublicationViewDataSource: class {
    func outroViewProperties(for pagedPublicationView: PagedPublicationView) -> OutroViewProperties?
    func configure(outroView: OutroView, for pagedPublicationView: PagedPublicationView)
    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String?
    func errorView(with error: Error?, for pagedPublicationView: PagedPublicationView) -> UIView?
}

// MARK: -

public class PagedPublicationView: UIView {
    
    public typealias PublicationId = CoreAPI.PagedPublication.Identifier
    public typealias PublicationModel = CoreAPI.PagedPublication
    public typealias PageModel = CoreAPI.PagedPublication.Page
    public typealias HotspotModel = CoreAPI.PagedPublication.Hotspot
    
    public typealias CoreProperties = (pageCount: Int?, bgColor: UIColor, aspectRatio: Double)
    
    public weak var delegate: PagedPublicationViewDelegate?
    public weak var dataSource: PagedPublicationViewDataSource?
    
    public func reload(publicationId: PublicationId, initialPageIndex: Int = 0, initialProperties: CoreProperties = (nil, .white, 1.0)) {
        
        self.coreProperties = initialProperties
        self.publicationState = .loading(publicationId)
        self.pagesState = .loading(publicationId)
        self.hotspotsState = .loading(publicationId)
        
        // change what we are showing based on the states
        updateCurrentViewState(initialPageIndex: initialPageIndex)
        
        // TODO: what if reload different after starting to load? need to handle id change
        
        delegate?.didStartReloading(in: self)
        
        // do the loading
        self.dataLoader.cancelLoading()
        self.dataLoader.startLoading(publicationId: publicationId, publicationLoaded: { [weak self] in self?.publicationDidLoad(forId: publicationId, initialPageIndex: initialPageIndex, result: $0) }, pagesLoaded: { [weak self] in self?.pagesDidLoad(forId: publicationId, initialPageIndex: initialPageIndex, result: $0) }, hotspotsLoaded: { [weak self] in self?.hotspotsDidLoad(forId: publicationId, initialPageIndex: initialPageIndex, result: $0) })
    }
    
    public func jump(toPageIndex pageIndex: Int, animated: Bool) {
        // TODO: if loading then save pageIndex for after load finished
        contentsView.versoView.jump(toPageIndex: pageIndex, animated: animated)
    }
    
    /// Tell the page publication that it is now visible again.
    /// (eg. when a view that was placed over the top of this view is removed, and the content becomes visible again).
    /// This will restart event collection. You MUST remember to call this if you previously called `didEnterBackground`, otherwise
    /// the PagePublicationView will not function correctly.
    public func didEnterForeground() {
        // start listening for the app going into the background
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActiveNotification), name: .UIApplicationWillResignActive, object: nil)
        lifecycleEventTracker?.didAppear()
    }
    
    /// Tell the page publication that it is no longer visible.
    /// (eg. a view has been placed over the top of the PagedPublicationView, so the content is no longer visible)
    /// This will pause event collection, until `didEnterForeground` is called again.
    public func didEnterBackground() {
        // stop listening for going into the background
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillResignActive, object: nil)
        lifecycleEventTracker?.didDisappear()
    }
    
    // MARK: - UIView Lifecycle
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentsView.frame = frame
        self.contentsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(self.contentsView)
        self.contentsView.versoView.delegate = self
        self.contentsView.versoView.dataSource = self
        
        addSubview(self.loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: layoutMarginsGuide.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
            ])
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
    }
    
    // MARK: - Internal
    
    enum LoadingState<Id, Model> {
        case unloaded
        case loading(Id)
        case loaded(Id, Model)
        case error(Id, Error)
    }

    enum ViewState {
        case initial
        case loading(bgColor: UIColor)
        case contents(coreProperties: CoreProperties, additionalLoading: Bool)
        case error(bgColor: UIColor, error: Error)
        
        init(coreProperties: CoreProperties,
             publicationState: LoadingState<PublicationId, PublicationModel>,
             pagesState: LoadingState<PublicationId, [PageView.Properties]>,
             hotspotsState: LoadingState<PublicationId, [HotspotModel]>) {
            
            switch (publicationState, pagesState, hotspotsState) {
            case (.error(_, let error), _, _),
                 (_, .error(_, let error), _):
                // the publication failed to load, or the pages failed.
                // either way, it's an error, so show an error (preferring the publication error)
                self = .error(bgColor: coreProperties.bgColor, error: error)
            case (_, _, _) where coreProperties.pageCount == nil:
                // we dont have a pageCount, so show spinner (even if pages or hotspots have loaded)
                self = .loading(bgColor: coreProperties.bgColor)
            case (_, _, .loading),
                 (_, .loading, _),
                 (.loading, _, _):
                // we have a page count, but still loading publication or hotpots or pages, so show the contents with a spinner
                self = .contents(coreProperties: coreProperties, additionalLoading: true)
            case (.loaded, _, _):
                // publication is loaded (pages & hotspots loaded or error)
                self = .contents(coreProperties: coreProperties, additionalLoading: false)
            default:
                self = .initial
            }
        }
    }
    
    var coreProperties: CoreProperties = (nil, .white, 1.0)
    var publicationState: LoadingState<PublicationId, PublicationModel> = .unloaded
    var pagesState: LoadingState<PublicationId, [PageView.Properties]> = .unloaded
    var hotspotsState: LoadingState<PublicationId, [HotspotModel]> = .unloaded
    var currentViewState: ViewState = .initial
    
    public var dataLoader: PagedPublicationViewDataLoader = PagedPublicationView.CoreAPILoader()
    public var imageLoader: PagedPublicationViewImageLoader? = PagedPublicationView.KingfisherImageLoader()
    public var eventHandler: PagedPublicationViewEventHandler? = PagedPublicationView.EventsHandler()
    
    let contentsView = PagedPublicationView.ContentsView()
    let loadingView = PagedPublicationView.LoadingView()
    //    fileprivate let errorView = PagedPublicationView.ErrorView()
    let hotspotOverlayView = HotspotOverlayView()
    
    lazy var outroOutsideTapGesture: UITapGestureRecognizer = { [weak self] in
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapOutsideOutro))
        tap.cancelsTouchesInView = false
        self?.addGestureRecognizer(tap)
        return tap
        }()
    
    var lifecycleEventTracker: PagedPublicationView.LifecycleEventTracker?
    
    // MARK: - Data Loading
    
    private func publicationDidLoad(forId publicationId: PublicationId, initialPageIndex: Int?, result: Result<PublicationModel>) {
        switch result {
        case .success(let publicationModel):
            self.publicationState = .loaded(publicationId, publicationModel)
            
            // update coreProperties using the publication
            self.coreProperties = (pageCount: publicationModel.pageCount,
                                   bgColor: publicationModel.branding.color ?? self.coreProperties.bgColor,
                                   aspectRatio: publicationModel.aspectRatio)
            
            // successful reload, event handler can now call opened & didAppear (if new publication, or we havnt called it yet)
            if lifecycleEventTracker?.publicationModel.id != publicationModel.id, let eventHandler = self.eventHandler {
                
                lifecycleEventTracker = PagedPublicationView.LifecycleEventTracker(publicationModel: publicationModel, eventHandler: eventHandler)
                lifecycleEventTracker?.opened()
                lifecycleEventTracker?.didAppear()
            }
            
            delegate?.didLoad(publication: publicationModel, in: self)
        case .error(let error):
            self.publicationState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: initialPageIndex)
    }
    
    private func pagesDidLoad(forId publicationId: PublicationId, initialPageIndex: Int?, result: Result<[PageModel]>) {
        switch result {
        case .success(let pageModels):
            // generate page view states based on the pageModels
            self.pagesState = .loaded(publicationId, pageModels.map({ .init(pageTitle: $0.title ?? String($0.index + 1),
                                                                            isBackgroundDark: self.isBackgroundDark,
                                                                            aspectRatio: CGFloat($0.aspectRatio),
                                                                            images: $0.images) }))
            
            delegate?.didLoad(pages: pageModels, in: self)
        case .error(let error):
            self.pagesState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: initialPageIndex)
    }
    
    private func hotspotsDidLoad(forId publicationId: PublicationId, initialPageIndex: Int?, result: Result<[HotspotModel]>) {
        switch result {
        case .success(let hotspotModels):
            self.hotspotsState = .loaded(publicationId, hotspotModels)
            self.delegate?.didLoad(hotspots: hotspotModels, in: self)
        case .error(let error):
            self.hotspotsState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: initialPageIndex)
    }
    
    // MARK: View updating
    
    // given the loading states (and coreProperties, generate the correct viewState
    private func updateCurrentViewState(initialPageIndex: Int?) {
        
        let oldViewState = self.currentViewState
        
        // Based on the pub/pages/hotspots states, return the state of the view
        currentViewState = ViewState(coreProperties: self.coreProperties,
                                     publicationState: self.publicationState,
                                     pagesState: self.pagesState,
                                     hotspotsState: self.hotspotsState)
        
        // change what views are visible (and update them) based on the viewState
        switch self.currentViewState {
        case .initial:
            self.loadingView.alpha = 0
            self.contentsView.alpha = 0
            self.backgroundColor = .white
        case let .loading(bgColor):
            self.loadingView.alpha = 1
            self.contentsView.alpha = 0
            self.backgroundColor = bgColor
            
            //TODO: change loading foreground color
        case let .contents(coreProperties, _):
            self.loadingView.alpha = 0
            self.contentsView.alpha = 1
            self.backgroundColor = coreProperties.bgColor
            
            // TODO: use additionalLoading value to show mini-spinner
            updateContentsViewLabels()
        case let .error(bgColor, error):
            self.loadingView.alpha = 0
            self.contentsView.alpha = 0
            self.backgroundColor = bgColor
            
            // TODO: GET & show error view
            print("Showing error", error)
        }
        
        // reload the verso based on the change to the pageCount
        switch (currentViewState, oldViewState) {
        case let (.contents(coreProperties, _), .contents(oldProperties, _)) where oldProperties.pageCount == coreProperties.pageCount:
            self.contentsView.versoView.reconfigureVisiblePages()
        default:
            self.contentsView.versoView.reloadPages(targetPageIndex: initialPageIndex)
        }
    }
    
    // refresh the properties of the contentsView based on the current state
    func updateContentsViewLabels() {
        var properties = contentsView.properties
        
        let currentPageIndexes = contentsView.versoView.currentPageIndexes
        
        // TODO: hide progress if showing outro
        if let pageCount = coreProperties.pageCount,
            let firstVisiblePageIndex = currentPageIndexes.first {
            
            properties.updateProgress(pageCount: pageCount, pageIndex: firstVisiblePageIndex)
            
            properties.pageLabelString = dataSourceWithDefaults.textForPageNumberLabel(pageIndexes: currentPageIndexes,
                                                                            pageCount: pageCount,
                                                                            for: self)
        } else {
            properties.progress = nil
            properties.pageLabelString = nil
        }
        
        properties.isBackgroundBlack = self.isBackgroundDark
        
        contentsView.update(properties: properties)
    }
    
    // MARK: Derived Values
    
    var dataSourceWithDefaults: PagedPublicationViewDataSource {
        return self.dataSource ?? self
    }
    
    var pageCount: Int {
        return coreProperties.pageCount ?? 0
    }
    var outroViewProperties: OutroViewProperties? {
        return dataSourceWithDefaults.outroViewProperties(for: self)
    }
    var outroPageIndex: Int? {
        return outroViewProperties != nil && pageCount > 0 ? pageCount : nil
    }
    var outroView: OutroView? {
        guard let outroIndex = outroPageIndex else {
            return nil
        }
        return contentsView.versoView.getPageViewIfLoaded(outroIndex)
    }
    func isOutroPage(inPageIndexes pageIndexSet: IndexSet) -> Bool {
        guard let outroIndex = self.outroPageIndex else { return false }
        return pageIndexSet.contains(outroIndex)
    }
    
    var isOutroPageVisible: Bool {
        return isOutroPage(inPageIndexes: contentsView.versoView.visiblePageIndexes)
    }

    func hotspots(onPageIndexes pageIndexSet: IndexSet) -> [HotspotModel] {
        guard case .loaded(_, let hotspotModels) = self.hotspotsState else {
            return []
        }
        return hotspotModels.filter({
            IndexSet($0.pageLocations.keys).contains(integersIn: pageIndexSet)
        })
    }
    
    var isBackgroundDark: Bool {
        // TODO: based on self.backgroundColor
        return false
    }
    
    // Get the properties for a page, based on the pages state
    func pageViewProperties(forPageIndex pageIndex: Int) -> PageView.Properties {
        guard case .loaded(_, let pageProperties) = self.pagesState, (0 ..< pageProperties.count).contains(pageIndex) else {
            // return an 'empty' page view
            return .init(pageTitle: String(pageIndex+1),
                         isBackgroundDark: self.isBackgroundDark,
                         aspectRatio: CGFloat(self.coreProperties.aspectRatio),
                         images: nil)
        }
        
        return pageProperties[pageIndex]
    }
    
    // MARK: -
    
    @objc
    fileprivate func didTapOutsideOutro(_ tap: UITapGestureRecognizer) {
        guard self.isOutroPageVisible, let outroView = self.outroView else {
            return
        }
        
        let location = tap.location(in: outroView)
        if outroView.bounds.contains(location) == false {
            jump(toPageIndex: pageCount-1, animated: true)
        }
    }
    
    @objc
    fileprivate func willResignActiveNotification(_ notification: Notification) {
        // once in the background, listen for coming back to the foreground again
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActiveNotification), name: .UIApplicationDidBecomeActive, object: nil)
        didEnterBackground()
    }
    @objc
    fileprivate func didBecomeActiveNotification(_ notification: Notification) {
        // once in the foreground, stop listen for that again
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        didEnterForeground()
    }
}

// MARK: -

private typealias PageViewDelegate = PagedPublicationView
extension PageViewDelegate: PagedPublicationPageViewDelegate {
    func didFinishLoading(viewImage imageURL: URL, fromCache: Bool, in pageView: PagedPublicationView.PageView) {
        
        let pageIndex = pageView.pageIndex

        // tell the spread that the image loaded.
        // Will be ignored if page isnt part of the spread
        lifecycleEventTracker?.spreadLifecycleTracker?.pageLoaded(pageIndex: pageIndex)
        
        delegate?.didFinishLoadingPageImage(imageURL: imageURL, pageIndex: pageIndex, in: self)
    }
}

// MARK: - 

private typealias HotspotDelegate = PagedPublicationView
extension HotspotDelegate: HotspotOverlayViewDelegate {
    
    func didTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        lifecycleEventTracker?.spreadLifecycleTracker?.pageTapped(pageIndex: pageIndex, location: locationInPage, hittingHotspots: (hotspots.count > 0))
        delegate?.didTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    func didLongPressHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        lifecycleEventTracker?.spreadLifecycleTracker?.pageLongPressed(pageIndex: pageIndex, location: locationInPage)
        delegate?.didLongPress(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    
    func didDoubleTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        lifecycleEventTracker?.spreadLifecycleTracker?.pageDoubleTapped(pageIndex: pageIndex, location: locationInPage)
        delegate?.didDoubleTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
}

// MARK: -

public extension PagedPublicationViewDelegate {
    func pageIndexesChanged(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView) {}
    func pageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView) {}
    func didFinishLoadingPageImage(imageURL: URL, pageIndex: Int, in pagedPublicationView: PagedPublicationView) {}
    
    // MARK: Hotspot events
    func didTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
    func didLongPress(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
    func didDoubleTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
    
    // MARK: Outro events
    func outroDidAppear(_ outroView: OutroView, in pagedPublicationView: PagedPublicationView) {}
    func outroDidDisappear(_ outroView: OutroView, in pagedPublicationView: PagedPublicationView) {}
    
    // MARK: Loading events
    func didStartReloading(in pagedPublicationView: PagedPublicationView) {}
    func didLoad(publication publicationModel: PagedPublicationView.PublicationModel, in pagedPublicationView: PagedPublicationView) {}
    func didLoad(pages pageModels: [PagedPublicationView.PageModel], in pagedPublicationView: PagedPublicationView) {}
    func didLoad(hotspots hotspotModels: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
}

// MARK: -

public extension PagedPublicationViewDataSource {
    func outroViewProperties(for pagedPublicationView: PagedPublicationView) -> OutroViewProperties? { return nil }
    func configure(outroView: OutroView, for pagedPublicationView: PagedPublicationView) { }
    
    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String? {
        guard let first = pageIndexes.first, let last = pageIndexes.last else {
            return nil
        }
        if first == last {
            return "\(first+1) / \(pageCount)"
        } else {
            return "\(first+1)-\(last+1) / \(pageCount)"
        }
    }
    func errorView(with error: Error?, for pagedPublicationView: PagedPublicationView) -> UIView? {
        return nil
    }
}
extension PagedPublicationView: PagedPublicationViewDataSource { }
