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
class PagedPublicationGraphLoader : NSObject, PagedPublicationLoaderProtocol {

    public var publicationId: String
    public var preloadedBackgroundColor:UIColor?
    public var preloadedPageCount:Int = 0
    
    
    convenience init(publicationId:String) {
        self.init(publicationId: publicationId, preloadedBackgroundColor:nil, preloadedPageCount:0)
    }
    init(publicationId:String, preloadedBackgroundColor:UIColor?, preloadedPageCount:Int) {
        self.publicationId = publicationId
        self.preloadedBackgroundColor = preloadedBackgroundColor
        self.preloadedPageCount = preloadedPageCount
    }
    
    
    func load(publicationLoaded:@escaping PagedPublicationLoaderProtocol.PublicationLoadedHandler,
              pagesLoaded:@escaping PagedPublicationLoaderProtocol.PagesLoadedHandler,
              hotspotsLoaded:@escaping PagedPublicationLoaderProtocol.HotspotsLoadedHandler) {
        
        // FIXME: do graph fetching
    }
    
}
