///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import CoreGraphics
import Foundation
import Future
import TjekAPI

//public typealias PublicationLoader = Future<Result<Publication_v2, APIError>>
//
//extension PublicationLoader {
//    public static func v2APILoader(publicationId: PublicationId, api: TjekAPI = .shared) -> PublicationLoader {
//        api.send(.getPublication(withId: publicationId))
//    }
//    public static func modelLoader(_ publication: Publication_v2) -> PublicationLoader {
//        .init(value: .success(publication))
//    }
//}
//
//public typealias PagedPublicationLoader = Future<Result<(publication: Publication_v2, pagesLoader: Future<Result<[PublicationPage_v2], APIError>>, hotspotsLoader: Future<Result<[PublicationHotspot_v2], APIError>>), APIError>>
//
//extension PagedPublicationLoader {
//    func startLoading(publicationLoaded: @escaping (Result<Publication_v2, APIError>) -> Void,
//                      pagesLoaded: @escaping (Result<[PublicationPage_v2], APIError>) -> Void,
//                      hotspotsLoaded: @escaping (Result<[PublicationHotspot_v2], APIError>) -> Void) {
//        self
//            .receiving(on: .main)
//            .run {
//                switch $0 {
//                case let .success((publication, pagesLoader, hotspotsLoader)):
//                    publicationLoaded(.success(publication))
//
//                    pagesLoader
//                        .receiving(on: .main)
//                        .run(pagesLoaded)
//
//                    hotspotsLoader
//                        .receiving(on: .main)
//                        .run(hotspotsLoaded)
//
//                case let .failure(error):
//                    publicationLoaded(.failure(error))
//                }
//            }
//    }
//    public static func v2APILoader(publicationLoader: PublicationLoader, api: TjekAPI = .shared) -> PagedPublicationLoader {
//        publicationLoader
//            .mapResult({ publication in
//                (
//                    publication,
//                    api.send(.getPublicationPages(withId: publication.id, aspectRatio: publication.aspectRatio)),
//                    api.send(.getPublicationHotspots(withId: publication.id, aspectRatio: publication.aspectRatio))
//                )
//            })
//    }
//
//    public static func v2APILoader(publicationId: PublicationId, api: TjekAPI = .shared) -> PagedPublicationLoader {
//        v2APILoader(publicationLoader: .v2APILoader(publicationId: publicationId, api: api), api: api)
//    }
//
//    public static func modelLoader(publication: Publication_v2, pages: [PublicationPage_v2], hotspots: [PublicationHotspot_v2]) -> PagedPublicationLoader {
//        .init(value: .success((
//            publication,
//            .init(value: .success(pages)),
//            .init(value: .success(hotspots))
//        )))
//    }
//}

extension PagedPublicationView {

    class v2APILoader: PagedPublicationViewDataLoader {
        typealias PublicationLoadedHandler = ((Result<PublicationModel, APIError>) -> Void)
        typealias PagesLoadedHandler = ((Result<[PageModel], APIError>) -> Void)
        typealias HotspotsLoadedHandler = ((Result<[HotspotModel], APIError>) -> Void)
        
        fileprivate let api: TjekAPI
        
        init(api: TjekAPI = .shared) {
            self.api = api
        }
        
        func startLoading(publicationId: PublicationId, publicationLoaded: @escaping PublicationLoadedHandler, pagesLoaded: @escaping PagesLoadedHandler, hotspotsLoaded: @escaping HotspotsLoadedHandler) {
            api.send(.getPublication(withId: publicationId)) { [weak self] (pubResult) in
                // trigger the publication loaded callback
                publicationLoaded(pubResult)

                guard case .success(let publication) = pubResult else {
                    // dont do any further requests if pub load failed
                    return
                }

                // start requesting pages
                self?.api.send(.getPublicationPages(withId: publicationId, aspectRatio: publication.aspectRatio)) { pagesResult in
                    pagesLoaded(pagesResult)
                }

                // start requesting hotspots
                self?.api.send(.getPublicationHotspots(withId: publicationId, aspectRatio: publication.aspectRatio)) { hotspotsResult in
                    hotspotsLoaded(hotspotsResult)
                }
            }
        }
    }
}

extension APIRequest {
    
    /// Fetch all the pages for the specified publication
    static func getPublicationPages(withId pubId: PublicationId, aspectRatio: Double? = nil) -> APIRequest<[PublicationPage_v2], API_v2> {
        APIRequest<[v2ImageURLs], API_v2>(
            endpoint: "catalogs/\(pubId)/pages",
            method: .GET
        ).map({ pageURLs in
            pageURLs.enumerated().map {
                let images = $0.element.imageURLSet
                let pageIndex = $0.offset
                return .init(index: pageIndex, title: "\(pageIndex+1)", aspectRatio: aspectRatio ?? 1.0, images: images)
            }
        })
    }
    
    /// Fetch all hotspots for the specified publication
    /// The `aspectRatio` (w/h) of the publication is needed in order to position the hotspots correctly
    static func getPublicationHotspots(withId pubId: PublicationId, aspectRatio: Double) -> APIRequest<[PublicationHotspot_v2], API_v2> {
        APIRequest<[PublicationHotspot_v2], API_v2>(
            endpoint: "catalogs/\(pubId)/hotspots",
            method: .GET
        ).map({ hotspots in
            hotspots.map({
                /// We do this to convert out of the awful old V2 coord system (which was x: 0->1, y: 0->(h/w))
                $0.withScaledBounds(scale: CGPoint(x: 1, y: aspectRatio))
            })
        })
    }
}
