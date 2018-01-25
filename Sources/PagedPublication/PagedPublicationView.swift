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

public protocol PagedPublicationViewLoader {
    typealias PublicationLoadedHandler = ((Result<CoreAPI.PagedPublication>) -> Void)
    typealias PagesLoadedHandler = ((Result<[CoreAPI.PagedPublication.Page]>) -> Void)
    typealias HotspotsLoadedHandler = ((Result<[CoreAPI.PagedPublication.Hotspot]>) -> Void)

    func startLoading(publicationId: PagedPublicationView.PublicationId, publicationLoaded: @escaping PublicationLoadedHandler, pagesLoaded: @escaping PagesLoadedHandler, hotspotsLoaded: @escaping HotspotsLoadedHandler)
    func cancelLoading()
}

public protocol PagedPublicationViewDataSource: class {
    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String?
}

public extension PagedPublicationViewDataSource {

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

public class PagedPublicationView: UIView {
    
    public typealias PublicationId = CoreAPI.PagedPublication.Identifier
    
    public struct BasicProperties {
        public var pageCount: Int
        public var bgColor: UIColor
        public var aspectRatio: Double
        
        public init(pageCount: Int, bgColor: UIColor, aspectRatio: Double) {
            self.pageCount = pageCount
            self.bgColor = bgColor
            self.aspectRatio = aspectRatio
        }
        
        public static var empty = BasicProperties(pageCount: 0, bgColor: .white, aspectRatio: 1.0)
    }
    
    public func reload(publicationId: PublicationId, openPageIndex: Int = 0, basicProperties: BasicProperties = .empty) {
        
        // enter loading state
        self.openPageIndex = openPageIndex
        self.state = .loading(publicationId: publicationId, properties: basicProperties)
        
        // do the loading
        self.loader.cancelLoading()
        self.loader.startLoading(publicationId: publicationId, publicationLoaded: { [weak self] in self?.publicationDidLoad(forId: publicationId, result: $0) }, pagesLoaded: { [weak self] in self?.pagesDidLoad(forId: publicationId, result: $0) }, hotspotsLoaded: { [weak self] in self?.hotspotsDidLoad(forId: publicationId, result: $0) })
    }
    
    public weak var dataSource: PagedPublicationViewDataSource?
    
    // MARK: UIView Lifecycle -
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentsView.frame = frame
        self.contentsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(self.contentsView)
        
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
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // change the bottom offset of the pageLabel when on iPhoneX
        if #available(iOS 11.0, *),
            UIDevice.current.userInterfaceIdiom == .phone,
            UIScreen.main.nativeBounds.height == 2436 { // iPhoneX
            // position above the home indicator on iPhoneX
            contentsView.pageLabelBottomOffset = contentsView.bounds.maxY - contentsView.safeAreaLayoutGuide.layoutFrame.maxY
        }
    }
    
    
    // MARK: -
    
    enum State {
        case initial
        case loading(publicationId: PublicationId, properties: BasicProperties)
        case loaded(publicationId: PublicationId, properties: BasicProperties, publication: CoreAPI.PagedPublication?, pages: [CoreAPI.PagedPublication.Page]?, hotspots: [CoreAPI.PagedPublication.Hotspot]?)
        case error(publicationId: PublicationId, properties: BasicProperties, error: Error)
    }
    
    
    var state: State = .initial {
        didSet {
            print("State did change", state)
            configureView(state: state)
        }
    }
    
    var loader: PagedPublicationViewLoader = PagedPublicationView.CoreAPILoader()
    
    var openPageIndex: Int = 0
    
    // MARK: private utility accessors
    
    private var loadedPublicationId: PublicationId? {
        guard case let .loaded(loadedPubId, _, _, _, _) = self.state else {
            return nil
        }
        return loadedPubId
    }
    
    private func loadedModels(forId publicationId: PublicationId) -> (publication: CoreAPI.PagedPublication?, pages: [CoreAPI.PagedPublication.Page]?, hotspots: [CoreAPI.PagedPublication.Hotspot]?) {
        guard case let .loaded(loadedPubId, _, publication, pages, hotspots) = self.state, loadedPubId == publicationId else {
            return (nil, nil, nil)
        }
        return (publication, pages, hotspots)
    }
    
    private var currentBasicProperties: BasicProperties {
        switch self.state {
        case .error(_, let properties, _),
             .loading(_, let properties),
             .loaded(_, let properties, _, _, _):
            return properties
        case .initial:
            return .empty
        }
    }
    
    private func publicationDidLoad(forId publicationId: PublicationId, result: Result<CoreAPI.PagedPublication>) {
        
        switch result {
        case .success(let publication):
            let loadedModels = self.loadedModels(forId: publicationId)
            
            // update the properties with what we can take from the publication
            var properties = self.currentBasicProperties
            properties.pageCount = publication.pageCount
            properties.bgColor = publication.branding.color ?? properties.bgColor
            properties.aspectRatio = publication.aspectRatio
            
            self.state = .loaded(publicationId: publicationId, properties: properties, publication: publication, pages: loadedModels.pages, hotspots: loadedModels.hotspots)
        case .error(let error):
            self.state = .error(publicationId: publicationId, properties: self.currentBasicProperties, error: error)
            break;
        }
    }
    private func pagesDidLoad(forId publicationId: PublicationId, result: Result<[CoreAPI.PagedPublication.Page]>) {
//        print("pages loaded", result)
    }
    private func hotspotsDidLoad(forId publicationId: PublicationId, result: Result<[CoreAPI.PagedPublication.Hotspot]>) {
//        print("hotspots loaded", result)
    }
    
    // MARK: Views
    
    fileprivate let contentsView = PagedPublicationView.ContentsView()
    fileprivate let loadingView = PagedPublicationView.LoadingView()
//    fileprivate let errorView = PagedPublicationView.ErrorView()

    func configureView(state: State) {
        
        switch state {
        case .initial:
            self.loadingView.alpha = 0
            self.contentsView.alpha = 0
            self.backgroundColor = .white
        case let .loading(_, properties):
            // TODO: allow for custom loadingView
            self.loadingView.alpha = 1
            self.contentsView.alpha = 0
            
            self.backgroundColor = properties.bgColor
            
        case let .loaded(_, properties, _, _, _):
            self.loadingView.alpha = 0
            self.contentsView.alpha = 1

            let bgColor = properties.bgColor
            let pageCount = properties.pageCount
            let openPageIndex = pageCount / 2 //TODO: use real value
            let isBackgroundBlack = false // TODO: use real value

            // TODO: get from datasource
            let pageTitle = "\(openPageIndex+1) / \(pageCount)"
            //dataSource?.textForPageNumberLabel(pageIndexes: <#T##IndexSet#>, pageCount: pageCount, for: self)
            
            let progress = min(1, max(0, pageCount > 0 ? Double(openPageIndex) / Double(pageCount) : 0))

            self.backgroundColor = bgColor
            self.contentsView.state = .init(progress: progress, isBackgroundBlack: isBackgroundBlack, pageNumberLabel: pageTitle)

        case let .error(_, properties, _):
            self.loadingView.alpha = 0
            self.contentsView.alpha = 0
            
            self.backgroundColor = properties.bgColor
        // TODO: GET & show error view
            
        }
    }
}

