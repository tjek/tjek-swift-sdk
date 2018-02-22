//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension PagedPublicationView {
    
    class CoreAPILoader: PagedPublicationViewDataLoader {
        
        internal var coreAPI: CoreAPI?
        internal var cancelTokens: [Cancellable] = []
        
        typealias PublicationLoadedHandler = ((Result<CoreAPI.PagedPublication>) -> Void)
        typealias PagesLoadedHandler = ((Result<[CoreAPI.PagedPublication.Page]>) -> Void)
        typealias HotspotsLoadedHandler = ((Result<[CoreAPI.PagedPublication.Hotspot]>) -> Void)
        
        func startLoading(publicationId: PagedPublicationView.PublicationId, publicationLoaded: @escaping PublicationLoadedHandler, pagesLoaded: @escaping PagesLoadedHandler, hotspotsLoaded: @escaping HotspotsLoadedHandler) {
            
            let coreAPI = self.coreAPI ?? ShopGun.coreAPI
            
            let pubReq = CoreAPI.Requests.getPagedPublication(withId: publicationId)
            
            let pubToken = coreAPI.request(pubReq) { [weak self] (pubResult) in
                // trigger the publication loaded callback
                publicationLoaded(pubResult)
                
                guard case .success(let publication) = pubResult else {
                    // dont do any further requests if pub load failed
                    return
                }
                
                // start requesting pages
                let pageReq = CoreAPI.Requests.getPagedPublicationPages(withId: publicationId, aspectRatio: publication.aspectRatio)
                let pagesToken = coreAPI.request(pageReq, completion: pagesLoaded)
                self?.cancelTokens.append(pagesToken)
                
                // start requesting hotspots
                let hotspotReq = CoreAPI.Requests.getPagedPublicationHotspots(withId: publicationId, aspectRatio: publication.aspectRatio)
                let hotspotsToken = coreAPI.request(hotspotReq, completion: hotspotsLoaded)
                self?.cancelTokens.append(hotspotsToken)
            }
            
            cancelTokens.append(pubToken)
        }
        func cancelLoading() {
            cancelTokens.forEach {
                $0.cancel()
            }
        }
    }
}
