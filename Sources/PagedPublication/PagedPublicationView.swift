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

/// The object that knows how to load/cache the page images from a URL
/// Loosely based on `Kingfisher` interface
public protocol PagedPublicationImageLoader: class {
    func loadImage(in imageView: UIImageView, url: URL, transition: (fadeDuration: TimeInterval, forced: Bool), completion: @escaping ((Result<(image: UIImage, fromCache: Bool)>, URL) -> Void))
    func cancelImageLoad(for imageView: UIImageView)
}

public typealias OutroView = VersoPageView
public typealias OutroViewProperties = (viewClass: OutroView.Type, width: CGFloat, maxZoom: CGFloat)

public protocol PagedPublicationViewDelegate: class {
    
    func outroViewProperties(for pagedPublicationView: PagedPublicationView) -> OutroViewProperties?
    func configure(outroView: OutroView, for pagedPublicationView: PagedPublicationView)
    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String?
}

public extension PagedPublicationViewDelegate {
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
}

extension PagedPublicationView: PagedPublicationViewDelegate { }

// MARK: -

public class PagedPublicationView: UIView {
    
    public typealias PublicationId = CoreAPI.PagedPublication.Identifier
    public typealias PublicationModel = CoreAPI.PagedPublication
    public typealias PageModel = CoreAPI.PagedPublication.Page
    public typealias HotspotModel = CoreAPI.PagedPublication.Hotspot
    
    public typealias CoreProperties = (pageCount: Int?, bgColor: UIColor, aspectRatio: Double)
    
    public weak var delegate: PagedPublicationViewDelegate?
    
    public func reload(publicationId: PublicationId, initialPageIndex: Int = 0, initialProperties: CoreProperties = (nil, .white, 1.0)) {
        
        self.coreProperties = initialProperties
        self.publicationState = .loading(publicationId)
        self.pagesState = .loading(publicationId)
        self.hotspotsState = .loading(publicationId)
        
        // change what we are showing based on the states
        updateCurrentViewState(initialPageIndex: initialPageIndex)
        
        // TODO: what if reload different after starting to load? need to handle id change
        
        // do the loading
        self.dataLoader.cancelLoading()
        self.dataLoader.startLoading(publicationId: publicationId, publicationLoaded: { [weak self] in self?.publicationDidLoad(forId: publicationId, initialPageIndex: initialPageIndex, result: $0) }, pagesLoaded: { [weak self] in self?.pagesDidLoad(forId: publicationId, initialPageIndex: initialPageIndex, result: $0) }, hotspotsLoaded: { [weak self] in self?.hotspotsDidLoad(forId: publicationId, initialPageIndex: initialPageIndex, result: $0) })
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
    public var imageLoader: PagedPublicationImageLoader? = PagedPublicationView.SimpleImageLoader()
    
    let contentsView = PagedPublicationView.ContentsView()
    let loadingView = PagedPublicationView.LoadingView()
    //    fileprivate let errorView = PagedPublicationView.ErrorView()
    let hotspotOverlayView = HotspotOverlayView()
    
    // MARK: - Data Loading
    
    private func publicationDidLoad(forId publicationId: PublicationId, initialPageIndex: Int?, result: Result<PublicationModel>) {
        switch result {
        case .success(let publicationModel):
            self.publicationState = .loaded(publicationId, publicationModel)
            
            // update coreProperties using the publication
            self.coreProperties = (pageCount: publicationModel.pageCount,
                                   bgColor: publicationModel.branding.color ?? self.coreProperties.bgColor,
                                   aspectRatio: publicationModel.aspectRatio)
            
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
        case .error(let error):
            self.pagesState = .error(publicationId, error)
        }
        
        self.updateCurrentViewState(initialPageIndex: initialPageIndex)
    }
    
    private func hotspotsDidLoad(forId publicationId: PublicationId, initialPageIndex: Int?, result: Result<[HotspotModel]>) {
        switch result {
        case .success(let hotspotModels):
            self.hotspotsState = .loaded(publicationId, hotspotModels)
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
            
            properties.pageLabelString = delegateWithDefaults.textForPageNumberLabel(pageIndexes: currentPageIndexes,
                                                                            pageCount: pageCount,
                                                                            for: self)
        } else {
            properties.progress = nil
            properties.pageLabelString = nil
        }
        
        properties.isBackgroundBlack = false // TODO: use real value based on coreProperties
        
        contentsView.update(properties: properties)
    }
    
    // MARK: Derived Values
    
    var delegateWithDefaults: PagedPublicationViewDelegate {
        return self.delegate ?? self
    }
    
    var pageCount: Int {
        return coreProperties.pageCount ?? 0
    }
    var outroViewProperties: OutroViewProperties? {
        return delegateWithDefaults.outroViewProperties(for: self)
    }
    var outroPageIndex: Int? {
        return outroViewProperties != nil && pageCount > 0 ? pageCount : nil
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
    
    func isOutroPage(inPageIndexes pageIndexSet: IndexSet) -> Bool {
        guard let outroIndex = self.outroPageIndex else { return false }
        return pageIndexSet.contains(outroIndex)
    }
}

// MARK: -

private typealias PageViewDelegate = PagedPublicationView
extension PageViewDelegate: PagedPublicationPageViewDelegate {
    func didFinishLoading(viewImage imageURL: URL, fromCache: Bool, in pageView: PagedPublicationView.PageView) {
//        let pageIndex = pageView.pageIndex
        
        // TODO: eventHandler & delegate
        
        // tell the spread that the image loaded.
        // Will be ignored if page isnt part of the spread
//        lifecycleEventHandler?.spreadEventHandler?.pageLoaded(pageIndex: pageIndex)
        
//        delegate?.didFinishLoadingPageImage(imageURL: imageURL, pageIndex: pageIndex, in: self)
    }
}

// MARK: - 

private typealias HotspotDelegate = PagedPublicationView
extension HotspotDelegate: HotspotOverlayViewDelegate {
    
    func didTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        
//        lifecycleEventHandler?.spreadEventHandler?.pageTapped(pageIndex: pageIndex, location: locationInPage, hittingHotspots: (hotspots.count > 0))
//
//        delegate?.didTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    func didLongPressHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        
//        lifecycleEventHandler?.spreadEventHandler?.pageLongPressed(pageIndex: pageIndex, location: locationInPage)
//
//        delegate?.didLongPress(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
    
    func didDoubleTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {
        
//        lifecycleEventHandler?.spreadEventHandler?.pageDoubleTapped(pageIndex: pageIndex, location: locationInPage)
//
//        delegate?.didDoubleTap(pageIndex: pageIndex, locationInPage: locationInPage, hittingHotspots: hotspots, in: self)
    }
}
