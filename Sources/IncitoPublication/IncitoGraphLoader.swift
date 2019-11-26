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
import Future

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
    businessLoadedCallback: ((Result<GraphBusiness, Error>) -> Void)?
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
        .start(dataRequest: request) // -> FutureResult<Data>
//        .measure(print: " 📞 Downloaded")
        .flatMapResult({
            decodeGraphResponseData($0)
//                .measure(print: " ⚙️ Decoded")
        }) // -> FutureResult<(business: GraphBusiness, document: IncitoDocument)>
        .observe({ res in
            businessLoadedCallback?(res.map({ $0.business }))
        })
        .mapToIncitoLoader({ $0.map({ $0.document }) })
}

extension Future {
    func mapToIncitoLoader(_ f: @escaping (Response) -> Result<IncitoDocument, Error>) -> IncitoLoader {
        return IncitoLoader { cb in
            self.run {
                cb(f($0))
            }
        }
    }
    
    func flatMapToIncitoLoader(_ f: @escaping (Response) -> IncitoLoader) -> IncitoLoader {
        return IncitoLoader { cb in
            self.run { f($0).load(cb) }
        }
    }
}

func decodeGraphResponseData(_ jsonData: Data) -> FutureResult<(business: GraphBusiness, document: IncitoDocument)> {
    return Future(work: {
        Result<(business: GraphBusiness, document: IncitoDocument), Error>(catching: {

            let jsonObj = try JSONSerialization.jsonObject(with: jsonData, options: [])
            
            guard let jsonDict = jsonObj as? [String: [String: [String: [String: Any]]]],
                let incitoDict = jsonDict["data"]?["incito"] else {
                throw IncitoGraphLoaderError.invalidData
            }
            
            guard let document: IncitoDocument = try incitoDict["document"].flatMap({
                guard let jsonStr = String(data: try JSONSerialization.data(withJSONObject: $0), encoding: .utf8) else {
                    return nil
                }
                return try IncitoDocument(jsonDict: $0, jsonStr: jsonStr)
            }) else {
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
        self.primaryColor = (jsonDict["primaryColor"] as? String).flatMap(UIColor.init(webString:))
    }
}

struct GenericGraphResponse<DataType: Decodable>: Decodable {
    var data: DataType
}

extension GraphClient {
    func start(dataRequest: GraphRequestProtocol) -> FutureResult<Data> {
        return FutureResult<Data> { completion in
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
