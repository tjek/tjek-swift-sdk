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

extension CoreAPI {
    func request<R: CoreAPIMappableRequest>(_ request: R) -> Future<ShopGunSDK.Result<R.ResponseType>> {
        return Future { cb in
            self.request(request, completion: cb)
        }
    }
}

extension IncitoLoaderViewController {
    
    private func load(
        incitoIdLoader: Future<Incito.Result<IncitoGraphIdentifier>>,
        relatedPublicationId: CoreAPI.PagedPublication.Identifier?,
        featureLabels: [FeatureLabel],
        graphClient: GraphClient = GraphAPI.shared.client,
        businessLoaded: ((Incito.Result<GraphBusiness>) -> Void)? = nil,
        completion: ((Incito.Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool)>) -> Void)? = nil
        ) {
        
        // Keep track of the id of the incitoId once it is loaded.
        var expectedIncitoId: IncitoGraphIdentifier? = nil
        var firstLoadedIncitoId: IncitoGraphIdentifier? = nil
        
        // every time the loader is called, fetch the width of the screen
        let graphIncitoLoader: (IncitoGraphIdentifier) -> IncitoLoader = { graphId in
            Future<Double>(work: { [weak self] in Double(self?.view.frame.size.width ?? 0) })
                .asyncOnMain()
                .flatMap({ width in
                    IncitoGraphLoader(
                        id: graphId,
                        graphClient: graphClient,
                        width: width,
                        featureLabels: featureLabels,
                        businessLoadedCallback: { businessLoaded?($0) }
                    )
                })
        }
        
        // make a loader that first fetches the publication, then gets the incito id from that publication, then calls the graphLoader with that incitoId
        let loader = incitoIdLoader
            .observeSuccess({ expectedIncitoId = $0 })
            .flatMapResult(graphIncitoLoader)
        
        self.load(loader) { [weak self] vcResult in
            switch vcResult {
            case let .success(viewController):
                var firstSuccessfulReload: Bool = false
                if let incitoId = expectedIncitoId {
                    firstSuccessfulReload = (firstLoadedIncitoId != incitoId)
                    
                    if firstSuccessfulReload {
                        firstLoadedIncitoId = incitoId
                        self?.firstSuccessfulReload(incitoId: incitoId, relatedPublicationId: relatedPublicationId)
                    }
                }
                completion?(.success((viewController, firstSuccessfulReload)))
            case let .error(error):
                completion?(.error(error))
            }
        }
    }
    
    public func load(
        publicationId: CoreAPI.PagedPublication.Identifier,
        graphClient: GraphClient = GraphAPI.shared.client,
        featureLabels: [FeatureLabel] = [],
        publicationLoaded: ((Incito.Result<CoreAPI.PagedPublication>) -> Void)? = nil,
        businessLoaded: ((Incito.Result<GraphBusiness>) -> Void)? = nil,
        completion: ((Incito.Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool)>) -> Void)? = nil
        ) {
        
        let publicationReq = CoreAPI.Requests.getPagedPublication(withId: publicationId)
        
        let incitoIdLoader: Future<Incito.Result<IncitoGraphIdentifier>> = CoreAPI.shared
            .request(publicationReq)
            .map(Incito.Result.init(shopGunSDKResult:))
            .observe({ publicationLoaded?($0) })
            .map({
                switch $0 {
                case let .success(publication):
                    guard let incitoId = publication.incitoId else {
                        return .error(IncitoPublicationLoaderError.notAnIncitoPublication)
                    }
                    return .success(incitoId)
                case let .error(err):
                    return .error(err)
                }
            })
        
        self.load(
            incitoIdLoader: incitoIdLoader,
            relatedPublicationId: publicationId,
            featureLabels: featureLabels,
            graphClient: graphClient,
            businessLoaded: businessLoaded,
            completion: completion
        )
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
        featureLabels: [FeatureLabel] = [],
        businessLoaded: ((Incito.Result<GraphBusiness>) -> Void)? = nil,
        completion: ((Incito.Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool)>) -> Void)? = nil
        ) {
        
        let incitoIdLoader = Future<Incito.Result<IncitoGraphIdentifier>>(value: .success(graphId))
        
        self.load(
            incitoIdLoader: incitoIdLoader,
            relatedPublicationId: relatedPublicationId,
            featureLabels: featureLabels,
            graphClient: graphClient,
            businessLoaded: businessLoaded,
            completion: completion
        )
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
