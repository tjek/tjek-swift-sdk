//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import UIKit
import Incito

struct IncitoViewerQuery: GraphQuery {
    
    enum DeviceCategory: String {
        case mobile = "DEVICE_CATEGORY_MOBILE"
        case tablet = "DEVICE_CATEGORY_TABLET"
        case desktop = "DEVICE_CATEGORY_DESKTOP"
    }
    enum Orientation: String {
        case horizontal = "ORIENTATION_HORIZONTAL"
        case vertical = "ORIENTATION_VERTICAL"
    }
    enum PointerType: String {
        case fine = "POINTER_FINE"
        case coarse = "POINTER_COARSE"
    }
    
    var id: PublicationIdentifier
    var featureLabelWeights: [String: Double]
    var maxWidth: Int
    var deviceCategory: DeviceCategory
    var orientation: Orientation
    var pixelRatio: Double
    var pointer: PointerType
    var versionsSupported: [String]
    var locale: String? = Locale.autoupdatingCurrent.identifier
    var time: Date? = Date()

    // MARK:
    static let queryDocument: String = loadQueryFile(name: "IncitoViewer.graphql", bundle: .shopgunSDK)!

    var requestString: String { return IncitoViewerQuery.queryDocument }
    let operationName: String = "IncitoViewer"
    var variables: GraphDict? {
        var dict: GraphDict = [
            "id": id.rawValue,
            "featureLabels": featureLabelWeights.map({ ["key": $0, "value": $1] }),
            "maxWidth": maxWidth,
            "deviceCategory": deviceCategory.rawValue,
            "orientation": orientation.rawValue,
            "pixelRatio": pixelRatio,
            "pointer": pointer.rawValue,
            "versionsSupported": versionsSupported
        ]
        if let locale = self.locale {
            dict["locale"] = locale
        }
        if let time = self.time {
            dict["time"] = CoreAPI.dateFormatter.string(from: time)
        }
        
        return dict
    }
}

public struct GraphBusiness: Decodable {
    public typealias Identifier = ShopGunSDK.GenericIdentifier<GraphBusiness>
    
    public var id: Identifier
    public var coreId: CoreAPI.Dealer.Identifier
    public var name: String
    public var primaryColor: UIColor?
    
    enum CodingKeys: String, CodingKey {
        case id, coreId, name, primaryColor
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try c.decode(Identifier.self, forKey: .id)
        self.coreId = try c.decode(CoreAPI.Dealer.Identifier.self, forKey: .coreId)
        self.name = try c.decode(String.self, forKey: .name)
        
        if let colorRGBAStr = try c.decodeIfPresent(String.self, forKey: .primaryColor) {
            self.primaryColor = UIColor(webString: colorRGBAStr)
        }
    }
}
