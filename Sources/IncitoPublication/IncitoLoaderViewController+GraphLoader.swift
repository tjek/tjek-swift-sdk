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
import Future

enum IncitoPublicationLoaderError: Error {
    case notAnIncitoPublication
}

extension CoreAPI {
    func requestFuture<R: CoreAPIMappableRequest>(_ request: R) -> FutureResult<R.ResponseType> {
        return Future { cb in
            self.request(request, completion: cb)
        }
    }
}

extension IncitoLoaderViewController {
    
    private func load(
        incitoPublicationId: CoreAPI.PagedPublication.Identifier,
        incitoPropertyLoader: FutureResult<(graphId: IncitoGraphIdentifier, isAlsoPagedPublication: Bool)>,
        featureLabelWeights: [String: Double],
        graphClient: GraphClient = GraphAPI.shared.client,
        businessLoaded: ((Result<GraphBusiness, Error>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
        ) {
        
        // Keep track of the id of the incitoId once it is loaded.
        var expectedIncitoId: IncitoGraphIdentifier? = nil
        var firstLoadedIncitoId: IncitoGraphIdentifier? = nil
        var isAlsoPagedPublication: Bool = false
        
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
//            .measure(print: " 🌈 Incito Fully Loaded")
        }
        
        // make a loader that first fetches the publication, then gets the incito id from that publication, then calls the graphLoader with that incitoId
        let loader = incitoPropertyLoader
            .observeResultSuccess({
                expectedIncitoId = $0.graphId
                isAlsoPagedPublication = $0.isAlsoPagedPublication
            })
            .flatMapResult({
                graphIncitoLoader($0.graphId)
            })
        
        self.load(loader) { [weak self] vcResult in
            switch vcResult {
            case let .success(viewController):
                var firstSuccessfulReload: Bool = false
                if let incitoId = expectedIncitoId {
                    firstSuccessfulReload = (firstLoadedIncitoId != incitoId)
                    
                    if firstSuccessfulReload {
                        firstLoadedIncitoId = incitoId
                        self?.firstSuccessfulReload(incitoPublicationId: incitoPublicationId, isAlsoPagedPublication: isAlsoPagedPublication)
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
        
        let incitoPropertyLoader: FutureResult<(graphId: IncitoGraphIdentifier, isAlsoPagedPublication: Bool)> = CoreAPI.shared
            .requestFuture(publicationReq)
            .observe({ publicationLoaded?($0) })
            .map({
                switch $0 {
                case let .success(publication):
                    guard let incitoId = publication.incitoId else {
                        return .failure(IncitoPublicationLoaderError.notAnIncitoPublication)
                    }
                    
                    return .success((graphId: incitoId, isAlsoPagedPublication: !publication.isOnlyIncito))
                case let .failure(err):
                    return .failure(err)
                }
            })
        
        self.load(
            incitoPublicationId: publicationId,
            incitoPropertyLoader: incitoPropertyLoader,
            featureLabelWeights: featureLabelWeights,
            graphClient: graphClient,
            businessLoaded: businessLoaded,
            completion: completion
        )
    }
    
    /**
     Will start loading the incito specified by the publication, using the graphClient.
     
     During the loading process (but before the incito is completely parsed) the businessLoaded callback will be called, containing the GraphBusiness object associated with the Incito. You can use this to customize the screen (bg color etc) before the incito is fully loaded.
     
     Once the incito is fully parsed, and the view is ready to be shown, the completion handler will be called.
     
     If you specify a `lastReadPosition` it will scroll to this location once loading finishes. This is a 0-1 %, accessible via the `scrollProgress` property of the IncitoViewController.
     */
    public func load(
        publication: CoreAPI.PagedPublication,
        featureLabelWeights: [String: Double] = [:],
        graphClient: GraphClient = GraphAPI.shared.client,
        businessLoaded: ((Result<GraphBusiness, Error>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
        ) {
        
        // if the publication doesnt have a graphId, then just eject with an error
        guard let graphId = publication.incitoId else {
            self.load(IncitoLoader(value: .failure(IncitoPublicationLoaderError.notAnIncitoPublication))) { vcResult in
                completion?(vcResult.map({ ($0, false) }))
            }
            return
        }
        
        self.load(
            incitoPublicationId: publication.id,
            incitoPropertyLoader: .init(value: .success((graphId, !publication.isOnlyIncito))),
            featureLabelWeights: featureLabelWeights,
            graphClient: graphClient,
            businessLoaded: businessLoaded,
            completion: completion
        )
    }
    
    private func firstSuccessfulReload(incitoPublicationId: PagedPublicationCoreAPIIdentifier, isAlsoPagedPublication: Bool) {
        
        // On first successful load, trigger the incitoOpened event (if the events tracker has been configured)
        if EventsTracker.isConfigured {
            EventsTracker.shared.trackEvent(
                .incitoPublicationOpened(
                    incitoPublicationId,
                    isAlsoPagedPublication: isAlsoPagedPublication
                )
            )
        }
    }
}
