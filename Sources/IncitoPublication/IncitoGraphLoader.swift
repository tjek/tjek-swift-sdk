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

enum IncitoGraphLoaderError: Error {
    case invalidData
    case missingDocument
    case missingBusiness
}

public func IncitoGraphLoader(
    id: IncitoGraphIdentifier,
    graphClient: GraphClient,
    width: Double,
    featureLabelWeights: [String: Double] = [:],
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
        featureLabelWeights: featureLabelWeights,
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
//        .measure(print: " 📞 Downloaded")
        .flatMapResult({
            decodeGraphResponseData($0)
//                .measure(print: " ⚙️ Decoded")
        })
        .observe({ res in
            businessLoadedCallback?(res.map({ $0.business }))
        })
        .flatMapResult({
            IncitoDocumentLoader(
                document: $0.document,
                width: width
            )
        })
}

func decodeGraphResponseData(_ jsonData: Data) -> Future<Incito.Result<(business: GraphBusiness, document: IncitoPropertiesDocument)>> {
    return Future(work: {
        Incito.Result<(business: GraphBusiness, document: IncitoPropertiesDocument)>(catching: {

            let jsonObj = try JSONSerialization.jsonObject(with: jsonData, options: [])
            
            guard let jsonDict = jsonObj as? [String: [String: [String: [String: Any]]]],
                let incitoDict = jsonDict["data"]?["incito"] else {
                throw IncitoGraphLoaderError.invalidData
            }
            
            guard let document = try incitoDict["document"].map(IncitoPropertiesDocument.init(jsonDict:)) else {
                throw IncitoGraphLoaderError.missingDocument
            }
            
            guard let business = try incitoDict["business"].map(GraphBusiness.init(jsonDict:)) else {
                throw IncitoGraphLoaderError.missingBusiness
            }
            
            return (
                business: business,
                document: document
            )
        })
    })
}

extension GraphBusiness {
    init(jsonDict: [String: Any]) throws {
        
        guard
            let id = Identifier(rawValue: jsonDict["id"] as? String),
            let coreId = CoreAPI.Dealer.Identifier(rawValue: jsonDict["coreId"] as? String),
            let name = jsonDict["name"] as? String
        else {
            throw IncitoGraphLoaderError.invalidData
        }
        
        self.id = id
        self.coreId = coreId
        self.name = name
        self.primaryColor = (jsonDict["primaryColor"] as? String)
            .flatMap(Color.init(string:))?
            .uiColor
    }
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
