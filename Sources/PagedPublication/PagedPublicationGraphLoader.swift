//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

@objc(SGNPagedPublicationGraphLoader)
public class PagedPublicationGraphLoader: NSObject, PagedPublicationLoaderProtocol {
    
    public var publicationId: String
    public var preloadedPublication: PagedPublicationViewModelProtocol?
    public var sourceType: String { return "graph" }
    
    convenience init(publicationId: String) {
        self.init(publicationId: publicationId, preloaded: nil)
    }
    convenience init(preloaded viewModel: PagedPublicationViewModelProtocol) {
        self.init(publicationId: viewModel.publicationId, preloaded: viewModel)
    }
    convenience init(publicationId: String, ownerId: String?, bgColor: UIColor?, pageCount: Int, aspectRatio: CGFloat) {
        let preloadedVM = PagedPublicationViewModel(publicationId: publicationId, ownerId: (ownerId ?? ""), bgColor: (bgColor ?? UIColor.white), pageCount: pageCount, aspectRatio: aspectRatio)
        self.init(publicationId: publicationId, preloaded: preloadedVM)
    }
    init(publicationId: String, preloaded viewModel: PagedPublicationViewModelProtocol?) {
        self.publicationId = publicationId
        self.preloadedPublication = viewModel
    }
    
    public func load(publicationLoaded:@escaping PagedPublicationLoaderProtocol.PublicationLoadedHandler,
              pagesLoaded:@escaping PagedPublicationLoaderProtocol.PagesLoadedHandler,
              hotspotsLoaded:@escaping PagedPublicationLoaderProtocol.HotspotsLoadedHandler) {
        
        // TODO: do graph fetching
    }
    
}

extension PagedPublicationView {
    public func reload(fromGraph publicationId: String, jumpTo pageIndex: Int = 0) {
        
        let loader = PagedPublicationGraphLoader(publicationId: publicationId)
        
        reload(with: loader, jumpTo: pageIndex)
    }
}
