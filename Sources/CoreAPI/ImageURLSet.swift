//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public struct ImageURLSet: Equatable {

    public struct SizedImageURL: Equatable {
        public var size: CGSize
        public var url: URL
    }
    
    /// The urls & their sizes, sorted from smallest to largest by area
    public let sizedUrls: [SizedImageURL]
    
    public init(sizedUrls: [SizedImageURL]) {
        self.sizedUrls = sizedUrls.sorted {
            ($0.size.width * $0.size.height) < ($1.size.width * $1.size.height)
        }
    }
    
    public func url(fitting size: CGSize) -> URL? {
        let closest = size.closestFitting(sizes: self.sizedUrls.map({ ($0.size, $0.url) }), alwaysLargerIfPossible: true)
        return closest?.val
    }
    
    public var smallest: SizedImageURL? {
        return sizedUrls.first
    }
    public var largest: SizedImageURL? {
        return sizedUrls.last
    }
    // TODO: add different utility getters. eg. `largerThan`
}

extension ImageURLSet {
    
    struct CoreAPIImageURLs: Decodable {
        let thumb: URL?
        let view: URL?
        let zoom: URL?
    }
    
    init(fromCoreAPI imageURLs: CoreAPIImageURLs, aspectRatio: Double?) {
        let possibleURLs: [(url: URL?, maxSize: CGSize)] = [
            (imageURLs.thumb, CGSize(width: 177, height: 212)),
            (imageURLs.view, CGSize(width: 768, height: 1004)),
            (imageURLs.zoom, CGSize(width: 1536, height: 2008))
        ]
        
        let sizedURLs: [SizedImageURL] = possibleURLs.compactMap { (maybeURL, maxSize) in
            guard let url = maybeURL else { return nil }
            
            var fittingSize = maxSize
            if let ratio = aspectRatio, ratio != 0 {
                fittingSize = maxSize.scaledDownToAspectRatio(CGFloat(ratio))
            }
            
            return SizedImageURL(
                size: CGSize(width: round(fittingSize.width), height: round(fittingSize.height)),
                url: url)
        }
        self.init(sizedUrls: sizedURLs)
    }
}
