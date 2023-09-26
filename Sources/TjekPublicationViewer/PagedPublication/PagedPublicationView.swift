///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

#if !COCOAPODS // Cocoapods merges these modules
import TjekAPI
import TjekEventsTracker
#endif
import UIKit
import Verso

/// The object that does the fetching of the publication's
public protocol PagedPublicationViewDataLoader {
    typealias PublicationLoadedHandler = ((Result<PagedPublicationView.PublicationModel, APIError>) -> Void)
    typealias PagesLoadedHandler = ((Result<[PagedPublicationView.PageModel], APIError>) -> Void)
    typealias HotspotsLoadedHandler = ((Result<[PagedPublicationView.HotspotModel], APIError>) -> Void)
    typealias PageDecrationsLoadedHandler = ((Result<[PagedPublicationView.PageDecorationModel], APIError>) -> Void)
    
    func startLoading(publicationId: PublicationId, publicationLoaded: @escaping PublicationLoadedHandler, pagesLoaded: @escaping PagesLoadedHandler, hotspotsLoaded: @escaping HotspotsLoadedHandler, pageDecorationsLoaded: @escaping PageDecrationsLoadedHandler)
}

public protocol PagedPublicationViewDelegate: AnyObject {
    // MARK: Page Change events
    func pageIndexesChanged(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView)
    func pageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView)
    func didFinishLoadingPageImage(imageURL: URL, pageIndex: Int, in pagedPublicationView: PagedPublicationView)
    func didEndZooming(zoomScale: CGFloat)
    
    // MARK: Hotspot events
    func didTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
    func didLongPress(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
    func didDoubleTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
    
    // MARK: Page Decoration events
    func pageExternalURLChanged(with url: URL?, in publicationView: PagedPublicationView)
    
    // MARK: Outro events
    func outroDidAppear(_ outroView: PagedPublicationView.OutroView, in pagedPublicationView: PagedPublicationView)
    func outroDidDisappear(_ outroView: PagedPublicationView.OutroView, in pagedPublicationView: PagedPublicationView)
    
    // MARK: Loading events
    func didStartReloading(in pagedPublicationView: PagedPublicationView)
    func didLoad(publication publicationModel: PagedPublicationView.PublicationModel, in pagedPublicationView: PagedPublicationView)
    func didLoad(pages pageModels: [PagedPublicationView.PageModel], in pagedPublicationView: PagedPublicationView)
    func didLoad(hotspots hotspotModels: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView)
    func didLoad(pageDecorations pageDecorationModels: [PagedPublicationView.PageDecorationModel], in pagedPublicationView: PagedPublicationView)
    
    func backgroundColor(publication publicationModel: PagedPublicationView.PublicationModel, in pagedPublicationView: PagedPublicationView) -> UIColor?
}

public protocol PagedPublicationViewDataSource: AnyObject {
    func outroViewProperties(for pagedPublicationView: PagedPublicationView) -> PagedPublicationView.OutroViewProperties?
    func configure(outroView: PagedPublicationView.OutroView, for pagedPublicationView: PagedPublicationView)
    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String?
}

// MARK: -

public class PagedPublicationView: UIView {
    
    public typealias OutroView = VersoPageView
    public typealias OutroViewProperties = (viewClass: OutroView.Type, width: CGFloat, maxZoom: CGFloat)
    
    public typealias PublicationModel = Publication_v2
    public typealias PageModel = PublicationPage_v2
    public typealias HotspotModel = PublicationHotspot_v2
    public typealias PageDecorationModel = PublicationPageDecoration_v2
    
    public typealias CoreProperties = (pageCount: Int?, bgColor: UIColor, aspectRatio: Double)
    
    public weak var delegate: PagedPublicationViewDelegate?
    public weak var dataSource: PagedPublicationViewDataSource?
    public var shouldHidePageCountLabel: Bool {
      get { self.contentsView.shouldHidePageCountLabel }
      set { self.contentsView.shouldHidePageCountLabel = newValue }
    }
    
    fileprivate var postReloadPageIndex: Int = 0
    
    public func reload(publicationId: PublicationId, initialPageIndex: Int = 0, initialProperties: CoreProperties = (nil, .white, 1.0)) {
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            s.coreProperties = initialProperties
            s.publicationState = .loading(publicationId)
            s.pagesState = .loading(publicationId)
            s.hotspotsState = .loading(publicationId)
            s.pageDecorationsState = .loading(publicationId)
            
            // change what we are showing based on the states
            s.updateCurrentViewState(initialPageIndex: initialPageIndex)
            
            // TODO: what if reload different after starting to load? need to handle id change
            
            s.postReloadPageIndex = initialPageIndex
            
            s.delegate?.didStartReloading(in: s)
            
            // successful reload, event handler can now be created if needed (if new publication, or we havnt called it yet)
            if let tracker: TjekEventsTracker = (TjekEventsTracker.isInitialized ? TjekEventsTracker.shared : nil),
               (self?.eventHandler == nil || self?.eventHandler?.publicationId != publicationId) {
                self?.eventHandler = EventsHandler(eventsTracker: tracker, publicationId: publicationId)
                
                self?.eventHandler?.didOpenPublication()
            }
            
            // do the loading
            s.dataLoader.startLoading(publicationId: publicationId, publicationLoaded: { [weak self] in self?.publicationDidLoad(forId: publicationId, result: $0) },
                                      pagesLoaded: { [weak self] in self?.pagesDidLoad(forId: publicationId, result: $0) },
                                      hotspotsLoaded: { [weak self] in self?.hotspotsDidLoad(forId: publicationId, result: $0) },
                                      pageDecorationsLoaded: { [weak self] in self?.pageDecorationsDidLoad(forId: publicationId, result: $0) }
            )
        }
    }
    
    public func jump(toPageIndex pageIndex: Int, animated: Bool) {
        switch self.currentViewState {
        case .contents:
            contentsView.versoView.jump(toPageIndex: pageIndex, animated: animated)
        case .loading,
             .initial,
             .error:
            postReloadPageIndex = pageIndex
        }
    }
    
    // MARK: - UIView Lifecycle
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(self.contentsView)
        self.contentsView.alpha = 0
        self.contentsView.versoView.delegate = self
        self.contentsView.versoView.dataSource = self
        self.contentsView.pageExternalURLChangedCallback = { [weak self] url in
            guard let self = self else { return }
            self.delegate?.pageExternalURLChanged(with: url, in: self)
        }
        
        self.contentsView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentsView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentsView.topAnchor.constraint(equalTo: topAnchor),
            contentsView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        addSubview(self.loadingView)
        self.loadingView.alpha = 0
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: layoutMarginsGuide.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor)
        ])
        
        addSubview(self.errorView)
        self.errorView.alpha = 0
        self.errorView.retryButton.addTarget(self, action: #selector(didTapErrorRetryButton), for: .touchUpInside)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorView.centerXAnchor.constraint(equalTo: layoutMarginsGuide.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor), {
                let con = errorView.widthAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.widthAnchor)
                con.priority = .defaultHigh
                return con
            }(), {
                let con = errorView.heightAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.heightAnchor)
                con.priority = .defaultHigh
                return con
            }()
        ])
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public var backgroundColor: UIColor? {
        set {
            super.backgroundColor = newValue
            
            var whiteComponent: CGFloat = 1.0
            newValue?.getWhite(&whiteComponent, alpha: nil)
            self.isBackgroundDark = whiteComponent <= 0.6
        }
        get { return super.backgroundColor }
    }
    
    var isBackgroundDark: Bool = false
    
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
             pagesState: LoadingState<PublicationId, [PageModel]>,
             hotspotsState: LoadingState<PublicationId, [IndexSet: [HotspotModel]]>,
             pageDecorationsState: LoadingState<PublicationId, [IndexSet: [PageDecorationModel]]>
        ) {
            
            switch (publicationState, pagesState, hotspotsState, pageDecorationsState) {
            case (.error(_, let error), _, _, _),
                 (_, .error(_, let error), _, _):
                // the publication failed to load, or the pages failed.
                // either way, it's an error, so show an error (preferring the publication error)
                self = .error(bgColor: coreProperties.bgColor, error: error)
            case (_, _, _, _) where (coreProperties.pageCount ?? 0) == 0:
                // we dont have a pageCount, so show spinner (even if pages or hotspots have loaded)
                self = .loading(bgColor: coreProperties.bgColor)
            case (_, _, _, .loading),
                 (_, _, .loading, _),
                 (_, .loading, _, _),
                 (.loading, _, _, _):
                // we have a page count, but still loading publication or hotpots or pages, so show the contents with a spinner
                self = .contents(coreProperties: coreProperties, additionalLoading: true)
            case (.loaded, _, _, _):
                // publication is loaded (pages & hotspots loaded or error)
                self = .contents(coreProperties: coreProperties, additionalLoading: false)
            default:
                self = .initial
            }
        }
    }
    
    public internal(set) var coreProperties: CoreProperties = (nil, .white, 1.0)
    var publicationState: LoadingState<PublicationId, PublicationModel> = .unloaded
    var pagesState: LoadingState<PublicationId, [PageModel]> = .unloaded
    var hotspotsState: LoadingState<PublicationId, [IndexSet: [HotspotModel]]> = .unloaded
    var pageDecorationsState: LoadingState<PublicationId, [IndexSet: [PageDecorationModel]]> = .unloaded
    var eventHandler: PagedPublicationView.EventsHandler?

    var currentViewState: ViewState = .initial
    
    public var dataLoader: PagedPublicationViewDataLoader = PagedPublicationView.v2APILoader()
    public var imageLoader: PagedPublicationViewImageLoader? = KingfisherImageLoader()
    
    /// The pan gesture used to change the pages.
    public var panGestureRecognizer: UIPanGestureRecognizer {
        return contentsView.versoView.panGestureRecognizer
    }
    
    /// This will return the OutroView (provided by the delegate) only after it has been configured.
    /// It is configured once the user has scrolled within a certain distance of the outro page (currently 10 pages).
    public var outroView: OutroView? {
        guard let outroIndex = outroPageIndex else {
            return nil
        }
        return contentsView.versoView.getPageViewIfLoaded(outroIndex)
    }
    
    public var isOutroPageVisible: Bool {
        return isOutroPage(inPageIndexes: contentsView.versoView.visiblePageIndexes)
    }
    
    public var pageCount: Int {
        return coreProperties.pageCount ?? 0
    }
    
    /// The page indexes of the spread that was centered when scrolling animations last ended
    public var currentPageIndexes: IndexSet {
        return self.contentsView.versoView.currentPageIndexes
    }
    
    /// The publication Id that is being loaded, has been loaded, or failed to load
    public var publicationId: PublicationId? {
        switch publicationState {
        case .unloaded:
            return nil
        case .loading(let id),
             .loaded(let id, _),
             .error(let id, _):
            return id
        }
    }
    /// The loaded Publication Model
    public var publicationModel: PublicationModel? {
        guard case .loaded(_, let model) = self.publicationState else { return nil }
        return model
    }
    
    public func hotspotModels(onPageIndexes pageIndexSet: IndexSet) -> [HotspotModel] {
        guard case .loaded(_, let hotspotModelsByPage) = self.hotspotsState else {
            return []
        }
        
        return hotspotModelsByPage.reduce(into: [], {
            if $1.key.contains(where: pageIndexSet.contains) {
                $0 += $1.value
            }
        })
    }
    
    public func pageDecorationModels(onPageIndexes pageIndexSet: IndexSet) -> [PageDecorationModel] {
        guard case .loaded(_, let pageDecorationModelsByPage) = self.pageDecorationsState else {
            return []
        }
        
        return pageDecorationModelsByPage.reduce(into: [], {
            if $1.key.contains(where: pageIndexSet.contains) {
                $0 += $1.value
            }
        })
    }
    
    public var pageModels: [PageModel]? {
        guard case .loaded(_, let models) = self.pagesState else { return nil }
        return models
    }
    
    /// Returns the pageview for the pageIndex, or nil if it hasnt been loaded yet
    public func pageViewIfLoaded(atPageIndex pageIndex: Int) -> UIView? {
        return self.contentsView.versoView.getPageViewIfLoaded(pageIndex)
    }
    
    /// Zooms out the publication
    public func resetPublicationZoom() {
        self.contentsView.versoView.zoomOut()
    }
    
    let contentsView = PagedPublicationView.ContentsView()
    let loadingView = PagedPublicationView.LoadingView()
    let errorView = PagedPublicationView.ErrorView()
    let hotspotOverlayView = HotspotOverlayView()
    
    lazy var outroOutsideTapGesture: UITapGestureRecognizer = { [weak self] in
        let tap = UITapGestureRecognizer(target: self, action: #selector(self?.didTapOutsideOutro))
        tap.cancelsTouchesInView = false
        self?.addGestureRecognizer(tap)
        return tap
        }()
    
    // MARK: - Data Loading
    
    private func publicationDidLoad(forId publicationId: PublicationId, result: Result<PublicationModel, APIError>) {
        switch result {
        case .success(let publicationModel):
            self.publicationState = .loaded(publicationId, publicationModel)
            
            let bgColor = self.delegate?.backgroundColor(publication: publicationModel, in: self) ?? publicationModel.branding.color ?? self.coreProperties.bgColor
            // update coreProperties using the publication
            self.coreProperties = (pageCount: publicationModel.pageCount,
                                   bgColor: bgColor,
                                   aspectRatio: publicationModel.aspectRatio)
            
            self.eventHandler?.didOpenPublicationPages(currentPageIndexes)
            
            delegate?.didLoad(publication: publicationModel, in: self)
        case .failure(let error):
            self.publicationState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: self.postReloadPageIndex)
    }
    
    private func pagesDidLoad(forId publicationId: PublicationId, result: Result<[PageModel], APIError>) {
        switch result {
        case .success(let pageModels):
            // generate page view states based on the pageModels
            self.pagesState = .loaded(publicationId, pageModels)
            delegate?.didLoad(pages: pageModels, in: self)
        case .failure(let error):
            self.pagesState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: self.postReloadPageIndex)
    }
    
    private func hotspotsDidLoad(forId publicationId: PublicationId, result: Result<[HotspotModel], APIError>) {
        switch result {
        case .success(let hotspotModels):
            // key hotspots by their pageLocations
            let hotspotsByPage: [IndexSet: [HotspotModel]] = hotspotModels.reduce(into: [:], {
                let pageKey = IndexSet($1.pageLocations.keys)
                $0[pageKey] = $0[pageKey, default: []] + [$1]
            })
            
            self.hotspotsState = .loaded(publicationId, hotspotsByPage)
            self.delegate?.didLoad(hotspots: hotspotModels, in: self)
        case .failure(let error):
            self.hotspotsState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: self.postReloadPageIndex)
    }
    
    private func pageDecorationsDidLoad(forId publicationId: PublicationId, result: Result<[PageDecorationModel], APIError>) {
        switch result {
        case .success(let pageDecorationModels):
            let pageDecorationsByPage: [IndexSet: [PageDecorationModel]] = pageDecorationModels.reduce(into: [:], {
                // normalize page indexes to be 0-based
                let normalizedPageIndex = IndexSet(integer: $1.pageNumber - 1)
                $0[normalizedPageIndex] = $0[normalizedPageIndex, default: []] + [$1]
            })
            
            self.pageDecorationsState = .loaded(publicationId, pageDecorationsByPage)
            self.delegate?.didLoad(pageDecorations: pageDecorationModels, in: self)
        case .failure(let error):
            self.pageDecorationsState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: self.postReloadPageIndex)
    }
    
    // MARK: View updating
    
    public func shouldHideLoadingSpinner(shouldHide: Bool) {
        self.contentsView.additionalLoadingSpinner.isHidden = shouldHide
    }
    
    // given the loading states (and coreProperties, generate the correct viewState
    private func updateCurrentViewState(initialPageIndex: Int?) {
        let oldViewState = self.currentViewState
        
        // Based on the pub/pages/hotspots states, return the state of the view
        currentViewState = ViewState(coreProperties: self.coreProperties,
                                     publicationState: self.publicationState,
                                     pagesState: self.pagesState,
                                     hotspotsState: self.hotspotsState,
                                     pageDecorationsState: self.pageDecorationsState)
        
        // change what views are visible (and update them) based on the viewState
        switch self.currentViewState {
        case .initial:
            self.loadingView.alpha = 0
            self.contentsView.alpha = 0
            self.errorView.alpha = 0
            self.backgroundColor = .white
            
        case let .loading(bgColor):
            self.loadingView.alpha = 1
            self.contentsView.alpha = 0
            self.errorView.alpha = 0
            self.backgroundColor = bgColor
            
        //TODO: change loading foreground color
        case let .contents(coreProperties, additionalLoading):
            self.loadingView.alpha = 0
            self.contentsView.alpha = 1
            self.errorView.alpha = 0
            self.backgroundColor = coreProperties.bgColor
            
            updateContentsViewLabels(pageIndexes: currentPageIndexes, additionalLoading: additionalLoading)
        case let .error(bgColor, error):
            self.loadingView.alpha = 0
            self.contentsView.alpha = 0
            self.errorView.alpha = 1
            self.backgroundColor = bgColor
            
            self.errorView.tintColor = self.isBackgroundDark ? UIColor.white : UIColor(white: 0, alpha: 0.7)
            self.errorView.update(for: error)
        }
        
        // reload the verso based on the change to the pageCount
        switch (currentViewState, oldViewState) {
        case let (.contents(coreProperties, _), .contents(oldProperties, _)) where oldProperties.pageCount == coreProperties.pageCount:
            self.contentsView.versoView.reconfigureVisiblePages()
            self.contentsView.versoView.reconfigureSpreadOverlay()
        default:
            self.contentsView.versoView.reloadPages(targetPageIndex: initialPageIndex)
        }
    }
    
    // refresh the properties of the contentsView based on the current state
    func updateContentsViewLabels(pageIndexes: IndexSet, additionalLoading: Bool) {
        var properties = contentsView.properties
        
        if let pageCount = coreProperties.pageCount,
            self.isOutroPage(inPageIndexes: pageIndexes) == false,
            self.isOutroPageVisible == false {
            
            properties.pageLabelString = dataSourceWithDefaults.textForPageNumberLabel(pageIndexes: pageIndexes,
                                                                                       pageCount: pageCount,
                                                                                       for: self)
            properties.pageDecoration = pageDecorationModels(onPageIndexes: pageIndexes).first
        } else {
            properties.pageLabelString = nil
            properties.pageDecoration = nil
        }
        
        properties.showAdditionalLoading = additionalLoading
        properties.isBackgroundBlack = self.isBackgroundDark
        
        contentsView.update(properties: properties)
    }
    
    // MARK: Derived Values
    
    var dataSourceWithDefaults: PagedPublicationViewDataSource {
        return self.dataSource ?? self
    }
    
    var outroViewProperties: OutroViewProperties? {
        return dataSourceWithDefaults.outroViewProperties(for: self)
    }
    var outroPageIndex: Int? {
        return outroViewProperties != nil && pageCount > 0 ? pageCount : nil
    }
    func isOutroPage(inPageIndexes pageIndexSet: IndexSet) -> Bool {
        guard let outroIndex = self.outroPageIndex else { return false }
        return pageIndexSet.contains(outroIndex)
    }
    
    // Get the properties for a page, based on the pages state
    func pageViewProperties(forPageIndex pageIndex: Int) -> PageView.Properties {
        guard case .loaded(_, let pageModels) = self.pagesState, pageModels.indices.contains(pageIndex) else {
            // return a 'loading' page view
            return .init(pageTitle: String(pageIndex+1),
                         isBackgroundDark: self.isBackgroundDark,
                         aspectRatio: CGFloat(self.coreProperties.aspectRatio),
                         images: nil)
        }
        
        let pageModel = pageModels[pageIndex]
        return .init(pageTitle: pageModel.title ?? String(pageModel.index + 1),
                     isBackgroundDark: self.isBackgroundDark,
                     aspectRatio: CGFloat(pageModel.aspectRatio),
                     images: pageModel.images)
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
    fileprivate func didTapErrorRetryButton(_ btn: UIButton) {
        guard let pubId = self.publicationId else { return }
        
        self.reload(publicationId: pubId, initialPageIndex: self.postReloadPageIndex, initialProperties: self.coreProperties)
    }
}

// MARK: -

private typealias PageViewDelegate = PagedPublicationView
extension PageViewDelegate: PagedPublicationPageViewDelegate {
    func didFinishLoading(viewImage imageURL: URL, fromCache: Bool, in pageView: PagedPublicationView.PageView) {
        delegate?.didFinishLoadingPageImage(imageURL: imageURL, pageIndex: pageView.pageIndex, in: self)
    }
}

// MARK: -

private typealias HotspotDelegate = PagedPublicationView
extension HotspotDelegate: HotspotOverlayViewDelegate {
    
    func didTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        delegate?.didTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    func didLongPressHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        delegate?.didLongPress(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    
    func didDoubleTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        delegate?.didDoubleTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
}
