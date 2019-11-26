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
        
        public init(size: CGSize, url: URL) {
            self.size = size
            self.url = url
        }
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
    
    init(fromCoreAPI imageURLs: CoreAPI.ImageURLs, aspectRatio: Double?) {
        let possibleURLs: [(url: URL?, maxSize: CGSize)] = [
            (imageURLs.thumb, CoreAPI.thumbSize),
            (imageURLs.view, CoreAPI.viewSize),
            (imageURLs.zoom, CoreAPI.zoomSize)
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
    
    public struct CoreAPI {
        public static var thumbSize = CGSize(width: 177, height: 212)
        public static var viewSize = CGSize(width: 768, height: 1004)
        public static var zoomSize = CGSize(width: 1536, height: 2008)
        
        struct ImageURLs: Decodable {
            let thumb: URL?
            let view: URL?
            let zoom: URL?
        }
    }
}
