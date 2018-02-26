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
        
        fileprivate enum RequestType: String {
            case publication
            case pages
            case hotspots
        }
        
        deinit {
            self.cancelLoading()
        }
        
        fileprivate var coreAPI: CoreAPI?
        fileprivate var cancelTokens: [RequestType: Cancellable] = [:]
        
        typealias PublicationLoadedHandler = ((Result<CoreAPI.PagedPublication>) -> Void)
        typealias PagesLoadedHandler = ((Result<[CoreAPI.PagedPublication.Page]>) -> Void)
        typealias HotspotsLoadedHandler = ((Result<[CoreAPI.PagedPublication.Hotspot]>) -> Void)
        
        func startLoading(publicationId: PagedPublicationView.PublicationId, publicationLoaded: @escaping PublicationLoadedHandler, pagesLoaded: @escaping PagesLoadedHandler, hotspotsLoaded: @escaping HotspotsLoadedHandler) {
            
            let coreAPI = self.coreAPI ?? ShopGun.coreAPI
            
            cancelLoading()
            
            let pubReq = CoreAPI.Requests.getPagedPublication(withId: publicationId)
            let pubToken = coreAPI.request(pubReq) { [weak self] (pubResult) in
                // trigger the publication loaded callback
                publicationLoaded(pubResult)
                
                self?.cancelTokens[.publication] = nil
                
                guard case .success(let publication) = pubResult else {
                    // dont do any further requests if pub load failed
                    return
                }
                
                // start requesting pages
                let pageReq = CoreAPI.Requests.getPagedPublicationPages(withId: publicationId, aspectRatio: publication.aspectRatio)
                let pagesToken = coreAPI.request(pageReq) { [weak self] (pagesResult) in
                    self?.cancelTokens[.pages] = nil
                    pagesLoaded(pagesResult)
                }
                self?.cancelTokens[.pages] = pagesToken
                
                // start requesting hotspots
                let hotspotReq = CoreAPI.Requests.getPagedPublicationHotspots(withId: publicationId, aspectRatio: publication.aspectRatio)
                let hotspotsToken = coreAPI.request(hotspotReq) { [weak self] (hotspotsResult) in
                    self?.cancelTokens[.hotspots] = nil
                    hotspotsLoaded(hotspotsResult)
                }
                self?.cancelTokens[.hotspots] = hotspotsToken
            }
            
            cancelTokens[.publication] = pubToken
        }
        func cancelLoading() {
            cancelTokens.forEach {
                $0.value.cancel()
            }
            cancelTokens = [:]
        }
    }
}
