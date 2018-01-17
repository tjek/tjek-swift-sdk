//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public struct ImageURLSet {
    public typealias SizedURL = (size: CGSize, url: URL)
    public let sizedUrls: [SizedURL]
    
    public init(sizedUrls: [SizedURL]) {
        // TODO: Store ordered from smallest to largest (based on area?)
        self.sizedUrls = sizedUrls
    }
    
    public func url(fitting size: CGSize) -> URL? {
        let closest = size.closestFitting(sizes: self.sizedUrls, alwaysLargerIfPossible: true)
        return closest?.val
    }
    
    // TODO: add different utility getters. eg. `smallest`, `largest`, `largerThan`
}

extension ImageURLSet {
    // Create using the standard CoreAPI thumb/view/zoom image urls, and an aspectRatio (if known)
    init(thumbURL: URL?, viewURL: URL?, zoomURL: URL?, aspectRatio: CGFloat? = nil) {
        let possibleURLs: [(url: URL?, maxSize: CGSize)] = [
            (thumbURL, CGSize(width: 177, height: 212)),
            (viewURL, CGSize(width: 768, height: 1004)),
            (zoomURL, CGSize(width: 1536, height: 2008))
        ]
        
        let sizedURLs: [SizedURL] = possibleURLs.flatMap { (maybeURL, maxSize) in
            guard let url = maybeURL else { return nil }
            
            var fittingSize = maxSize
            if let ratio = aspectRatio, ratio != 0 {
                fittingSize = maxSize.scaledDownToAspectRatio(ratio)
            }
            
            return (CGSize(width: round(fittingSize.width), height: round(fittingSize.height)), url)
        }
        self.init(sizedUrls: sizedURLs)
    }
}
