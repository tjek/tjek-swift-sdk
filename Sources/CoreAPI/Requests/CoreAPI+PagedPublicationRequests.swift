//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension CoreAPI.Requests {
    
    // TODO: add a load stores option?
    /// Fetch the details about the specified publication
    public static func getPagedPublication(withId pubId: CoreAPI.PagedPublication.Identifier) -> CoreAPI.Request<CoreAPI.PagedPublication> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)", method: .GET, timeoutInterval: 30)
    }
    
    /// Fetch all the pages for the specified publication
    public static func getPagedPublicationPages(withId pubId: CoreAPI.PagedPublication.Identifier, aspectRatio: Double? = nil) -> CoreAPI.Request<[CoreAPI.PagedPublication.Page]> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)/pages", method: .GET, timeoutInterval: 30, resultMapper: {
            return $0.map {
                // map the raw array of imageURLSets into objects containing page indexes
                let pageURLs = try JSONDecoder().decode([ImageURLSet.CoreAPIImageURLs].self, from: $0)
                return pageURLs.enumerated().map {
                    let images = ImageURLSet(fromCoreAPI: $0.element, aspectRatio: aspectRatio)
                    let pageIndex = $0.offset
                    return .init(index: pageIndex, title: "\(pageIndex+1)", aspectRatio: aspectRatio ?? 1.0, images: images)
                }
            }
        })
    }

    /// Fetch all hotspots for the specified publication
    /// The `aspectRatio` (w/h) of the publication is needed in order to position the hotspots correctly
    public static func getPagedPublicationHotspots(withId pubId: CoreAPI.PagedPublication.Identifier, aspectRatio: Double) -> CoreAPI.Request<[CoreAPI.PagedPublication.Hotspot]> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)/hotspots", method: .GET, timeoutInterval: 30, resultMapper: {
            return $0.map {
                return try JSONDecoder().decode([CoreAPI.PagedPublication.Hotspot].self, from: $0).map {
                    /// We do this to convert out of the awful old V2 coord system (which was x: 0->1, y: 0->(h/w))
                    return $0.withScaledBounds(scale: CGPoint(x: 1, y: aspectRatio))
                }
            }
        })
    }
}
