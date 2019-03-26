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

extension IncitoLoaderViewController {
    /**
     Will start loading the incito specified by the id, using the graphClient.
     
     During the loading process (but before the incito is completely parsed) the businessLoaded callback will be called, containing the GraphBusiness object associated with the Incito. You can use this to customize the screen (bg color etc) before the incito is fully loaded.
     
     Once the incito is fully parsed, and the view is ready to be shown, the completion handler will be called.
     
     If you specify a `lastReadPosition` it will scroll to this location once loading finishes. This is a 0-1 %, accessible via the `scrollProgress` property of the IncitoViewController.
     */
    public func load(
        id: IncitoGraphIdentifier,
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
                    id: id,
                    graphClient: graphClient,
                    width: width,
                    businessLoadedCallback: { businessLoaded?($0.shopGunSDKResult) }
                )
            })
        
        self.load(loader) { [weak self] vcResult in
            switch vcResult {
            case let .success(viewController):
                let firstSuccessfulReload = (loadedIncitoId != id)
                if firstSuccessfulReload {
                    loadedIncitoId = id
                    self?.firstSuccessfulReload(incitoId: id, relatedPublicationId: relatedPublicationId)
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
