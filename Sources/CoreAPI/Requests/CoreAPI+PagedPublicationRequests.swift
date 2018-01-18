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
    public static func getPagedPublication(withId pubId: CoreAPI.PagedPublication.Identifier) -> CoreAPI.Request<CoreAPI.PagedPublication> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)", method: .GET, timeoutInterval: 30)
    }
    
    public static func getPagedPublicationPages(withId pubId: CoreAPI.PagedPublication.Identifier, aspectRatio: CGFloat? = nil) -> CoreAPI.Request<[CoreAPI.PagedPublication.Page]> {
        return .init(path: "/v2/catalogs/\(pubId.rawValue)/pages", method: .GET, timeoutInterval: 30, resultMapper: {
            return $0.map {
                let pageURLs = try JSONDecoder().decode([ImageURLSet.CoreAPIImageURLs].self, from: $0)
                return pageURLs.enumerated().map {
                    let images = ImageURLSet(fromCoreAPI: $0.element, aspectRatio: aspectRatio)
                    let pageIndex = $0.offset
                    return .init(index: pageIndex, title: "\(pageIndex+1)", aspectRatio: Double(aspectRatio ?? 1.0), images: images)
                }
            }
        })
    }
}
