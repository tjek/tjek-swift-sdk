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
    func request<R: CoreAPIMappableRequest>(_ request: R) -> FutureResult<R.ResponseType> {
        return Future { cb in
            self.request(request, completion: cb)
        }
    }
}

extension IncitoLoaderViewController {
    
    private func load(
        incitoIdLoader: FutureResult<IncitoGraphIdentifier>,
        relatedPublicationId: CoreAPI.PagedPublication.Identifier?,
        featureLabelWeights: [String: Double],
        graphClient: GraphClient = GraphAPI.shared.client,
        businessLoaded: ((Result<GraphBusiness, Error>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
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
                        featureLabelWeights: featureLabelWeights,
                        businessLoadedCallback: { businessLoaded?($0) }
                    )
                })
        }
        
        // make a loader that first fetches the publication, then gets the incito id from that publication, then calls the graphLoader with that incitoId
        let loader = incitoIdLoader
            .observeResultSuccess({ expectedIncitoId = $0 })
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
            case let .failure(error):
                completion?(.failure(error))
            }
        }
    }
    
    public func load(
        publicationId: CoreAPI.PagedPublication.Identifier,
        featureLabelWeights: [String: Double] = [:],
        graphClient: GraphClient = GraphAPI.shared.client,
        publicationLoaded: ((Result<CoreAPI.PagedPublication, Error>) -> Void)? = nil,
        businessLoaded: ((Result<GraphBusiness, Error>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
        ) {
        
        let publicationReq = CoreAPI.Requests.getPagedPublication(withId: publicationId)
        
        let incitoIdLoader: FutureResult<IncitoGraphIdentifier> = CoreAPI.shared
            .request(publicationReq)
            .observe({ publicationLoaded?($0) })
            .map({
                switch $0 {
                case let .success(publication):
                    guard let incitoId = publication.incitoId else {
                        return .failure(IncitoPublicationLoaderError.notAnIncitoPublication)
                    }
                    return .success(incitoId)
                case let .failure(err):
                    return .failure(err)
                }
            })
        
        self.load(
            incitoIdLoader: incitoIdLoader,
            relatedPublicationId: publicationId,
            featureLabelWeights: featureLabelWeights,
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
        relatedPublicationId: PagedPublicationCoreAPIIdentifier?,
        featureLabelWeights: [String: Double] = [:],
        graphClient: GraphClient = GraphAPI.shared.client,
        businessLoaded: ((Result<GraphBusiness, Error>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
        ) {
        
        let incitoIdLoader = FutureResult<IncitoGraphIdentifier>(value: .success(graphId))
        
        self.load(
            incitoIdLoader: incitoIdLoader,
            relatedPublicationId: relatedPublicationId,
            featureLabelWeights: featureLabelWeights,
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
