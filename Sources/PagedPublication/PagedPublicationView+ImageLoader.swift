//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

/// The object that knows how to load/cache the page images from a URL
/// Loosely based on `Kingfisher` interface
public protocol PagedPublicationViewImageLoader: class {
    func loadImage(in imageView: UIImageView, url: URL, transition: (fadeDuration: TimeInterval, evenWhenCached: Bool), completion: @escaping ((Result<(image: UIImage, fromCache: Bool), Error>, URL) -> Void))
    func cancelImageLoad(for imageView: UIImageView)
}

extension PagedPublicationView {
    enum ImageLoaderError: Error {
        case unknownImageLoadError(url: URL)
        case cancelled
    }
}

extension Error where Self == PagedPublicationView.ImageLoaderError {
    var isCancellationError: Bool {
        switch self {
        case .cancelled:
            return true
        default:
            return false
        }
    }
}

// MARK: -

import Kingfisher

extension PagedPublicationView {
    
    /// This class wraps the Kingfisher library
    class KingfisherImageLoader: PagedPublicationViewImageLoader {
        
        init() {
            // max 150 Mb of disk cache
            KingfisherManager.shared.cache.maxDiskCacheSize = 150*1024*1024
        }
        
        func loadImage(in imageView: UIImageView, url: URL, transition: (fadeDuration: TimeInterval, evenWhenCached: Bool), completion: @escaping ((Result<(image: UIImage, fromCache: Bool), Error>, URL) -> Void)) {
            
            var options: KingfisherOptionsInfo = [.transition(.fade(transition.fadeDuration))]
            if transition.evenWhenCached == true {
                options.append(.forceTransition)
            }
            
            imageView.kf.setImage(with: url, options: options) { (image, error, cacheType, _) in
                if let img = image {
                    completion(.success((img, cacheType.cached)), url)
                } else {
                    let err: Error
                    // if it is a KingFisher cancellation error, convert into our own cancellation error
                    if let nsErr: NSError = error, nsErr.domain == KingfisherErrorDomain, nsErr.code == KingfisherError.downloadCancelledBeforeStarting.rawValue {
                        err = PagedPublicationView.ImageLoaderError.cancelled
                    } else {
                        err = error ?? PagedPublicationView.ImageLoaderError.unknownImageLoadError(url: url)
                    }
                    completion(.failure(err), url)
                }
            }
        }
        
        func cancelImageLoad(for imageView: UIImageView) {
            imageView.kf.cancelDownloadTask()
        }
    }
}
