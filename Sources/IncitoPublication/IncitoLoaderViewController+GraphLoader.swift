//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation
import Incito
import UIKit

enum IncitoPublicationLoaderError: Error {
    case notAnIncitoPublication
}

extension IncitoLoaderViewController {
    
    public func load(
        publicationId: CoreAPI.PagedPublication.Identifier,
        graphClient: GraphClient = GraphAPI.shared.client,
        publicationLoaded: ((Result<CoreAPI.PagedPublication>) -> Void)? = nil,
        businessLoaded: ((Result<GraphBusiness>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool)>) -> Void)? = nil
        ) {
        
        // Keep track of the id of the incitoId once it is loaded.
        var firstLoadedIncitoId: IncitoGraphIdentifier? = nil
        var publicationIncitoId: IncitoGraphIdentifier? = nil
        
        // every time the loader is called, fetch the width of the screen
        let graphLoader: (IncitoGraphIdentifier) -> IncitoLoader = { graphId in
            Future(work: { [weak self] in Double(self?.view.frame.size.width ?? 0) })
            .asyncOnMain()
            .flatMap({ width in
                IncitoGraphLoader(
                    id: graphId,
                    graphClient: graphClient,
                    width: width,
                    businessLoadedCallback: { businessLoaded?($0.shopGunSDKResult) }
                )
            })
        }
        
        // make a loader that first fetches the publication, then gets the incito id from that publication, then calls the graphLoader with that incitoId
        let loader = Future<ShopGunSDK.Result<CoreAPI.PagedPublication>>(run: { cb in
            let publicationReq = CoreAPI.Requests.getPagedPublication(withId: publicationId)
            CoreAPI.shared.request(publicationReq, completion: cb)
        })
            .observe({ publicationLoaded?($0) })
            .map({
                Incito.Result(shopGunSDKResult:
                    $0.mapValue({ (pub: CoreAPI.PagedPublication) -> IncitoGraphIdentifier in
                        if let incitoId = pub.incitoId {
                            publicationIncitoId = incitoId
                            return incitoId
                        } else {
                            throw IncitoPublicationLoaderError.notAnIncitoPublication
                        }
                    })
                )
            })
            .flatMapResult(graphLoader)
        
        self.load(loader) { [weak self] vcResult in
            switch vcResult {
            case let .success(viewController):
                var firstSuccessfulReload: Bool = false
                if let incitoId = publicationIncitoId {
                    firstSuccessfulReload = (firstLoadedIncitoId != incitoId)
                    
                    if firstSuccessfulReload {
                        firstLoadedIncitoId = incitoId
                        self?.firstSuccessfulReload(incitoId: incitoId, relatedPublicationId: publicationId)
                    }
                }
                completion?(.success((viewController, firstSuccessfulReload)))
            case let .error(error):
                completion?(.error(error))
            }
        }
    }
    /**
     Will start loading the incito specified by the id, using the graphClient.
     
     During the loading process (but before the incito is completely parsed) the businessLoaded callback will be called, containing the GraphBusiness object associated with the Incito. You can use this to customize the screen (bg color etc) before the incito is fully loaded.
     
     Once the incito is fully parsed, and the view is ready to be shown, the completion handler will be called.
     
     If you specify a `lastReadPosition` it will scroll to this location once loading finishes. This is a 0-1 %, accessible via the `scrollProgress` property of the IncitoViewController.
     */
    public func load(
        graphId: IncitoGraphIdentifier,
        graphClient: GraphClient = GraphAPI.shared.client,
        relatedPublicationId: PagedPublicationCoreAPIIdentifier?,
        businessLoaded: ((Result<GraphBusiness>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool)>) -> Void)? = nil
        ) {
        
        // Keep track of the id of the incitoId once it is loaded.
        var loadedIncitoId: IncitoGraphIdentifier? = nil
        
        // every time the loader is called, fetch the width of the screen
        let loader = Future<Double>(work: { [weak self] in Double(self?.view.frame.size.width ?? 0) })
            .asyncOnMain()
            .flatMap({ width in
                IncitoGraphLoader(
                    id: graphId,
                    graphClient: graphClient,
                    width: width,
                    businessLoadedCallback: { businessLoaded?($0.shopGunSDKResult) }
                )
            })
        
        self.load(loader) { [weak self] vcResult in
            switch vcResult {
            case let .success(viewController):
                let firstSuccessfulReload = (loadedIncitoId != graphId)
                if firstSuccessfulReload {
                    loadedIncitoId = graphId
                    self?.firstSuccessfulReload(incitoId: graphId, relatedPublicationId: relatedPublicationId)
                }
                completion?(.success((viewController, firstSuccessfulReload)))
            case let .error(error):
                completion?(.error(error))
            }
        }
    }
    
    private func firstSuccessfulReload(incitoId: IncitoGraphIdentifier, relatedPublicationId: PagedPublicationCoreAPIIdentifier?) {
        
        // On first successful load, trigger the incitoOpened event (if the events tracker has been configured)
        if EventsTracker.isConfigured {
            EventsTracker.shared.trackEvent(
                .incitoPublicationOpened(
                    incitoId,
                    pagedPublicationId: relatedPublicationId
                )
            )
        }
    }
}
