//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension PagedPublicationView {
    
    class SimpleImageLoader: PagedPublicationImageLoader {
        
        var tasks: [UIImageView: URLSessionTask] = [:]
        
        func loadImage(in imageView: UIImageView, url: URL, transition: (fadeDuration: TimeInterval, evenWhenCached: Bool), completion: @escaping ((Result<(image: UIImage, fromCache: Bool)>, URL) -> Void)) {

            let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
                self?.tasks[imageView] = nil
                if let err = error {
                    completion(.error(err), url)
                    return
                }
                guard let imgData = data, let image = UIImage(data: imgData) else {
                    completion(.error(NSError(domain: "Missing Image", code: 0, userInfo: nil)), url)
                    return
                }
                
                UIView.transition(with: imageView, duration: transition.fadeDuration, options: [.transitionCrossDissolve], animations: {
                    imageView.image = image
                }, completion: { (_) in
                    completion(.success((image: image, fromCache: false)), url)
                })
            }
            task.resume()
            tasks[imageView] = task
        }
        
        func cancelImageLoad(for imageView: UIImageView) {
//            print("Cancelling", imageView)
            tasks[imageView]?.cancel()
            tasks[imageView] = nil
        }
    }
}
