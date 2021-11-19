///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation
import Future
@_exported import Incito
#if !COCOAPODS // Cocoapods merges these modules
import TjekAPI
import TjekEventsTracker
import enum TjekUtils.JSONValue
#endif
import UIKit

enum IncitoAPIQueryError: Error {
    case invalidData
    case notAnIncitoPublication
}

struct IncitoAPIQuery: Encodable {

    enum DeviceCategory: String, Encodable {
        case mobile
        case tablet
        case desktop
    }
    enum Orientation: String, Encodable {
        case horizontal
        case vertical
    }
    enum PointerType: String, Encodable {
        case fine
        case coarse
    }

    var id: PublicationId
    var deviceCategory: DeviceCategory
    var orientation: Orientation
    var pointer: PointerType
    var pixelRatio: Double
    var maxWidth: Int
    var versionsSupported: [String]
    var localeCode: String?
    var time: Date?
    var featureLabels: [String: Double]
    
    var apiRequest: APIRequest<IncitoDocument, API_v4> {
        APIRequest<IncitoDocument, API_v4>(
            endpoint: "generate_incito_from_publication",
            body: .encodable(self),
            decoder: APIRequestDecoder { data, _ in
                guard let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                    let jsonStr = String(data: data, encoding: .utf8) else {
                        throw IncitoAPIQueryError.invalidData
                }
                
                return try IncitoDocument(jsonDict: jsonDict, jsonStr: jsonStr)
            }
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id,
             deviceCategory = "device_category",
             orientation,
             pointer,
             pixelRatio = "pixel_ratio",
             maxWidth = "max_width",
             versionsSupported = "versions_supported",
             localeCode = "locale_code",
             time,
             featureLabels = "feature_labels"
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(self.id, forKey: .id)
        try c.encode(self.deviceCategory, forKey: .deviceCategory)
        try c.encode(self.orientation, forKey: .orientation)
        try c.encode(self.pointer, forKey: .pointer)
        try c.encode(self.pixelRatio, forKey: .pixelRatio)
        try c.encode(self.maxWidth, forKey: .maxWidth)
        try c.encode(self.versionsSupported, forKey: .versionsSupported)
        try c.encode(self.localeCode, forKey: .localeCode)
        try c.encode(self.time, forKey: .time)
        
        let features: [[String: JSONValue]] = self.featureLabels.map({ ["key": $0.jsonValue, "value": $1.jsonValue] })
        try c.encode(features, forKey: .featureLabels)
    }
}

extension IncitoAPIQuery.DeviceCategory {
    init(device: UIDevice) {
        switch device.userInterfaceIdiom {
        case .pad:
            self = .tablet
        default:
            self = .mobile
        }
    }
}

extension IncitoLoaderViewController {
    
    private func load(
        incitoPublicationId: PublicationId,
        incitoPropertyLoader: FutureResult<(publicationId: PublicationId, isAlsoPagedPublication: Bool)>,
        featureLabelWeights: [String: Double],
        apiClient: TjekAPI,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
        ) {
        
        // Keep track of the id of the incitoId once it is loaded.
        var expectedIncitoId: PublicationId? = nil
        var firstLoadedIncitoId: PublicationId? = nil
        var isAlsoPagedPublication: Bool = false
        
        // every time the loader is called, fetch the width of the screen
        let incitoLoaderBuilder: (PublicationId) -> Future<Result<IncitoDocument, Error>> = { [weak self] incitoId in
            Future<IncitoAPIQuery>(work: { [weak self] in
                let viewWidth = Int(self?.view.frame.size.width ?? 0)
                let windowWidth = Int(self?.view.window?.frame.size.width ?? 0)
                let screenWidth = Int(UIScreen.main.bounds.size.width)
                let minWidth = 100
                // build the query on the main queue.
                return IncitoAPIQuery(
                    id: incitoId,
                    deviceCategory: .init(device: .current),
                    orientation: .vertical,
                    pointer: .coarse,
                    pixelRatio: Double(UIScreen.main.scale),
                    maxWidth: max(viewWidth >= minWidth ? viewWidth : windowWidth >= minWidth ? windowWidth : screenWidth, minWidth),
                    versionsSupported: IncitoEnvironment.supportedVersions,
                    localeCode: Locale.autoupdatingCurrent.identifier,
                    time: Date(),
                    featureLabels: featureLabelWeights
                )
            })
                .performing(on: .main)
                .flatMap({ query in apiClient.send(query.apiRequest) })
                .eraseToAnyError()
//                .measure(print: " 🌈 Incito Fully Loaded")
        }
        
        // make a loader that first fetches the publication, then gets the incito id from that publication, then calls the graphLoader with that incitoId
        let loader = IncitoLoader { callback in
            incitoPropertyLoader
                .observeResultSuccess({
                    expectedIncitoId = $0.publicationId
                    isAlsoPagedPublication = $0.isAlsoPagedPublication
                })
                .flatMapResult({
                    incitoLoaderBuilder($0.publicationId)
                })
                .run(callback)
        }
        
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
        publicationId: PublicationId,
        featureLabelWeights: [String: Double] = [:],
        apiClient: TjekAPI = .shared,
        publicationLoaded: ((Result<Publication_v2, Error>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
    ) {
        
        let incitoPropertyLoader: FutureResult<(publicationId: PublicationId, isAlsoPagedPublication: Bool)> = apiClient.send(.getPublication(withId: publicationId))
            .eraseToAnyError()
            .observe({ publicationLoaded?($0) })
            .map({
                switch $0 {
                case let .success(publication):
                    if publication.hasIncito {
                        return .success((publicationId: publication.id, isAlsoPagedPublication: publication.hasPagedPublication))
                    } else {
                        return .failure(IncitoAPIQueryError.notAnIncitoPublication)
                    }
                case let .failure(err):
                    return .failure(err)
                }
            })
        
        self.load(
            incitoPublicationId: publicationId,
            incitoPropertyLoader: incitoPropertyLoader,
            featureLabelWeights: featureLabelWeights,
            apiClient: apiClient,
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
        publication: Publication_v2,
        featureLabelWeights: [String: Double] = [:],
        apiClient: TjekAPI = .shared,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
        ) {
        
        // if the publication doesnt have a graphId, then just eject with an error
        guard publication.hasIncito else {
            self.load(IncitoLoader(load: { cb in cb(.failure(IncitoAPIQueryError.notAnIncitoPublication)) })) { vcResult in
                completion?(vcResult.map({ ($0, false) }))
            }
            return
        }
        
        self.load(
            incitoPublicationId: publication.id,
            incitoPropertyLoader: .init(value: .success((publication.id, publication.hasPagedPublication))),
            featureLabelWeights: featureLabelWeights,
            apiClient: apiClient,
            completion: completion
        )
    }
    
    private func firstSuccessfulReload(incitoPublicationId: PublicationId, isAlsoPagedPublication: Bool) {
        
        // On first successful load, trigger the incitoOpened event (if the events tracker has been configured)
        if TjekEventsTracker.isInitialized {
            TjekEventsTracker.shared.trackEvent(
                .incitoPublicationOpened(
                    incitoPublicationId,
                    isAlsoPagedPublication: isAlsoPagedPublication
                )
            )
        }
    }
}
