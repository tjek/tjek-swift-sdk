//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import Kingfisher

/// The object that knows how to load/cache the page images from a URL
/// Loosely based on `Kingfisher` interface
public protocol PagedPublicationViewImageLoader: class {
    func loadImage(in imageView: UIImageView, url: URL, transition: (fadeDuration: TimeInterval, evenWhenCached: Bool), completion: @escaping ((Result<(image: UIImage, fromCache: Bool)>, URL) -> Void))
    func cancelImageLoad(for imageView: UIImageView)
}

extension PagedPublicationView {
    
    enum ImageLoaderError: Error {
        case unknownImageLoadError(url: URL)
    }

    /// This class wraps the Kingfisher library
    class KingfisherImageLoader: PagedPublicationViewImageLoader {
        
        func loadImage(in imageView: UIImageView, url: URL, transition: (fadeDuration: TimeInterval, evenWhenCached: Bool), completion: @escaping ((Result<(image: UIImage, fromCache: Bool)>, URL) -> Void)) {
            
            var options: KingfisherOptionsInfo = [.transition(.fade(transition.fadeDuration))]
            if transition.evenWhenCached == true {
                options.append(.forceTransition)
            }
            
            imageView.kf.setImage(with: url, options: options) { (image, error, cacheType, _) in
                if let img = image {
                    completion(.success((img, cacheType.cached)), url)
                } else {
                    let err: Error = error ?? PagedPublicationView.ImageLoaderError.unknownImageLoadError(url: url)
                    completion(.error(err), url)
                }
            }
        }
        
        func cancelImageLoad(for imageView: UIImageView) {
            imageView.kf.cancelDownloadTask()
        }
    }
}
