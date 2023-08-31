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
    var enableLazyLoading: Bool
    
    var apiRequest: APIRequest<IncitoDocument> {
        APIRequest<IncitoDocument>.v4(
            endpoint: "generate_incito_from_publication",
            body: .encodable(self),
            responseDecoder: .init { data in
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
             featureLabels = "feature_labels",
             enableLazyLoading = "enable_lazy_loading"
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
        try c.encode(self.enableLazyLoading, forKey: .enableLazyLoading)
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
    
    public func load(
        publicationId: PublicationId,
        featureLabelWeights: [String: Double] = [:],
        enableLazyLoading: Bool = false,
        apiClient: some APIRequestSender = TjekAPI.shared,
        publicationLoaded: ((Result<Publication_v2, Error>) -> Void)? = nil,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
    ) {
        var hasLoadedIncito: Bool = false
        
        if TjekEventsTracker.isInitialized {
            TjekEventsTracker.shared.trackEvent(
                .incitoPublicationOpened(publicationId)
            )
        }
        
        if let publicationLoadedCallback = publicationLoaded {
            apiClient.send(.getPublication(withId: publicationId))
                .eraseToAnyError()
                .run(publicationLoadedCallback)
        }
        
        let loader = IncitoLoader { [weak self] callback in
            Future<IncitoAPIQuery>(work: { [weak self] in
                let viewWidth = Int(self?.view.frame.size.width ?? 0)
                let windowWidth = Int(self?.view.window?.frame.size.width ?? 0)
                let screenWidth = Int(UIScreen.main.bounds.size.width)
                let minWidth = 100
                // build the query on the main queue.
                return IncitoAPIQuery(
                    id: publicationId,
                    deviceCategory: .init(device: .current),
                    orientation: .vertical,
                    pointer: .coarse,
                    pixelRatio: Double(UIScreen.main.scale),
                    maxWidth: max(viewWidth >= minWidth ? viewWidth : windowWidth >= minWidth ? windowWidth : screenWidth, minWidth),
                    versionsSupported: IncitoEnvironment.supportedVersions,
                    localeCode: Locale.autoupdatingCurrent.identifier,
                    time: Date(),
                    featureLabels: featureLabelWeights,
                    enableLazyLoading: enableLazyLoading
                )
            })
                .performing(on: .main)
                .flatMap({ query in apiClient.send(query.apiRequest) })
                .eraseToAnyError()
//                .measure(print: " 🌈 Incito Fully Loaded")
                .run(callback)
        }
        
        self.load(loader) { vcResult in
            switch vcResult {
            case let .success(viewController):
                let firstLoad = !hasLoadedIncito
                hasLoadedIncito = true
                let prevHandler = viewController.sectionViewedEventHandler
                viewController.sectionViewedEventHandler = { event in
                    prevHandler(event)
                    
                    // ignore short events
                    guard event.duration > 0.3 else {
                        return
                    }
                    
                    if TjekEventsTracker.isInitialized {
                        TjekEventsTracker.shared.trackEvent(
                            .incitoPublicationSectionOpened(publicationId, sectionId: event.id.sectionId, sectionPosition: event.id.sectionPosition, openedAt: event.appeared, millisecsOnScreen: Int(event.duration * 1000))
                        )
                    }
                }
                completion?(.success((viewController, firstLoad)))
            case let .failure(error):
                completion?(.failure(error))
            }
        }
    }
    
    public func load(
        publication: Publication_v2,
        featureLabelWeights: [String: Double] = [:],
        enableLazyLoading: Bool = false,
        apiClient: some APIRequestSender = TjekAPI.shared,
        completion: ((Result<(viewController: IncitoViewController, firstSuccessfulLoad: Bool), Error>) -> Void)? = nil
        ) {
        
        // if the publication doesnt have a graphId, then just eject with an error
        guard publication.hasIncitoPublication else {
            self.load(IncitoLoader(load: { cb in cb(.failure(IncitoAPIQueryError.notAnIncitoPublication)) })) { vcResult in
                completion?(vcResult.map({ ($0, false) }))
            }
            return
        }
        
        self.load(
            publicationId: publication.id,
            featureLabelWeights: featureLabelWeights,
            enableLazyLoading: enableLazyLoading,
            apiClient: apiClient,
            completion: completion
        )
    }
}
