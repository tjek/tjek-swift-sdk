//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import UIKit
import Incito

public func IncitoGraphLoader(
    id: IncitoGraphIdentifier,
    graphClient: GraphClient,
    width: Double,
    timeout: TimeInterval = 10,
    businessLoadedCallback: ((Incito.Result<GraphBusiness>) -> Void)?
    ) -> IncitoLoader {
    
    let deviceCategory = UIDevice.current.incitoDeviceCategory
    let orientation = IncitoViewerQuery.Orientation.vertical
    let pixelRatio: Double = Double(UIScreen.main.scale)
    let supportedVersion = IncitoEnvironment.supportedVersions
    
    let locale = Locale.autoupdatingCurrent
    let date = Date()
    
    let query = IncitoViewerQuery(
        id: id,
        maxWidth: Int(width),
        deviceCategory: deviceCategory,
        orientation: orientation,
        pixelRatio: pixelRatio,
        pointer: .coarse,
        versionsSupported: supportedVersion,
        locale: locale.identifier,
        time: date
    )
    
    let request = GraphRequest(query: query, timeoutInterval: timeout)
    
    // - Load data from graph
    // - convert result to incito result type
    // - decode the graph response
    // - load the document
    return graphClient
        .start(dataRequest: request)
        .map(Incito.Result.init(shopGunSDKResult:))
        .flatMapResult(GenericGraphResponse<IncitoViewerGraphData>.decode(from:))
        .observe({ res in
            businessLoadedCallback?(res.map({ $0.data.incito.business }))
        })
        .flatMapResult({
            IncitoDocumentLoader(
                document: $0.data.incito.document,
                width: width
            )
        })
}

struct GenericGraphResponse<DataType: Decodable>: Decodable {
    var data: DataType
}

extension GraphClient {
    func start(dataRequest: GraphRequestProtocol) -> Future<ShopGunSDK.Result<Data>> {
        return Future<ShopGunSDK.Result<Data>> { completion in
            self.start(dataRequest: dataRequest, completion: completion)
        }
    }
}
extension UIDevice {
    var incitoDeviceCategory: IncitoViewerQuery.DeviceCategory {
        switch self.userInterfaceIdiom {
        case .pad:
            return .tablet
        default:
            return .mobile
        }
    }
}

extension Incito.Result {
    /// annoying mapping between Result types... roll-on swift 5
    init(shopGunSDKResult: ShopGunSDK.Result<A>) {
        switch shopGunSDKResult {
        case let .success(a):
            self = .success(a)
        case let .error(error):
            self = .error(error)
        }
    }
    
    var shopGunSDKResult: ShopGunSDK.Result<A> {
        switch self {
        case let .success(a):
            return .success(a)
        case let .error(error):
            return .error(error)
        }
    }
}
