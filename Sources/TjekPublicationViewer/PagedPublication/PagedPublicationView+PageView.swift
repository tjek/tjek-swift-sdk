///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

#if !COCOAPODS // Cocoapods merges these modules
import TjekAPI
import TjekUtils
#endif
import UIKit
import Verso

protocol PagedPublicationPageViewDelegate: AnyObject {
    func didConfigure(pageView: PagedPublicationView.PageView, with properties: PagedPublicationView.PageView.Properties)
    func didFinishLoading(viewImage imageURL: URL, fromCache: Bool, in pageView: PagedPublicationView.PageView)
    func didFinishLoading(zoomImage imageURL: URL, fromCache: Bool, in pageView: PagedPublicationView.PageView)
}

extension PagedPublicationPageViewDelegate {
    func didConfigure(pageView: PagedPublicationView.PageView, with properties: PagedPublicationView.PageView.Properties) {}
    func didFinishLoading(viewImage imageURL: URL, fromCache: Bool, in pageView: PagedPublicationView.PageView) {}
    func didFinishLoading(zoomImage imageURL: URL, fromCache: Bool, in pageView: PagedPublicationView.PageView) {}
}

extension PagedPublicationView {
    
    class PageView: VersoPageView {
        
        struct Properties: Equatable {
            var pageTitle: String
            var isBackgroundDark: Bool
            var aspectRatio: CGFloat
            var images: Set<ImageURL>?
            
            static var empty = Properties(pageTitle: "", isBackgroundDark: false, aspectRatio: 1.0, images: nil)
        }
        
        weak var delegate: PagedPublicationPageViewDelegate?
        weak var imageLoader: PagedPublicationViewImageLoader?
        
        var isViewImageLoaded: Bool {
            return imageLoadState == .loaded
        }
        func startLoadingZoomImageIfNotLoaded() {
            guard zoomImageLoadState == .notLoaded else { return }
            
            guard let zoomImageURL = properties?.images?.imageURL(widthAtLeast: 1500, fallbackToNearest: true)?.url else { return }
            
            self.startLoadingZoomImage(fromURL: zoomImageURL)
        }
        
        func configure(with properties: Properties) {
            
            let oldProperties = self.properties
            self.properties = properties
            
            if oldProperties?.images != properties.images {
                imageLoader?.cancelImageLoad(for: imageView)
                imageView.image = nil
                imageLoadState = .notLoaded
                
                imageLoader?.cancelImageLoad(for: zoomImageView)
                zoomImageView.image = nil
                zoomImageView.isHidden = true
                zoomImageLoadState = .notLoaded
            }
            
            pageLabel.text = properties.pageTitle
            pageLabel.textColor = properties.isBackgroundDark ? UIColor.white : UIColor(white: 0, alpha: 0.7)
            backgroundColor = properties.isBackgroundDark ? UIColor(white: 1, alpha: 0.1) : UIColor(white: 0.8, alpha: 0.15)
            
            if let imageURL = properties.images?.imageURL(widthAtLeast: 700, fallbackToNearest: true)?.url {
                startLoadingViewImage(fromURL: imageURL)
            }
            
            delegate?.didConfigure(pageView: self, with: properties)
            
        }
        
        private var properties: Properties?
        
        // MARK: - Subviews
        
        fileprivate var pageLabel: UILabel = {
            let view = UILabel(frame: CGRect.zero)
            view.textColor = UIColor(white: 0, alpha: 0.8)
            view.textAlignment = .center
            view.baselineAdjustment = .alignCenters
            return view
        }()
        
        fileprivate var imageView: UIImageView = {
            let view = UIImageView(frame: CGRect.zero)
            
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.contentMode = .scaleAspectFit
            
            return view
        }()
        
        fileprivate var zoomImageView: UIImageView = {
            let view = UIImageView(frame: CGRect.zero)
            
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.contentMode = .scaleAspectFit
            
            return view
        }()
        
        // MARK: - UIView Lifecycle
        
        required init(frame: CGRect) {
            super.init(frame: frame)
            
            isUserInteractionEnabled = false
            
            // add subviews
            addSubview(pageLabel)
            addSubview(imageView)
            addSubview(zoomImageView)
            
            backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)
            
            // must be started on non-main run loop to avoid interfering with scrolling
            self.perform(#selector(startPulsingNumberAnimation), with: nil, afterDelay: 0, inModes: [RunLoop.Mode.common])
            
            // listen for memory warnings and clear the zoomimage
            NotificationCenter.default.addObserver(self, selector: #selector(memoryWarningNotification), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        }
        
        required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
        
        override func layoutSubviews() {
            
            super.layoutSubviews()
            
            let fontSize = round(max(bounds.height, bounds.width) / 10)
            if pageLabel.font.pointSize != fontSize {
                pageLabel.font = UIFont.boldSystemFont(ofSize: fontSize)
            }
            
            pageLabel.frame = bounds
            imageView.frame = bounds
            zoomImageView.frame = bounds
        }
        
        override open func sizeThatFits(_ size: CGSize) -> CGSize {
            guard size.width > 0 && size.height > 0, let aspectRatio = properties?.aspectRatio else {
                return size
            }
            let containerAspectRatio = size.width / size.height
            
            // size based on aspect ratio
            var newSize = size
            if aspectRatio < containerAspectRatio {
                newSize.width = newSize.height * aspectRatio
            } else if aspectRatio > containerAspectRatio {
                newSize.height = newSize.width / aspectRatio
            }
            
            return newSize
        }
        
        // MARK: - Notifications
        
        @objc
        fileprivate func memoryWarningNotification(_ notification: Notification) {
            clearZoomImage(animated: true)
        }
        
        @objc
        fileprivate func startPulsingNumberAnimation() {
            UIView.animate(withDuration: 1, delay: 0, options: [.allowUserInteraction, .repeat, .autoreverse, .curveEaseIn], animations: {
                self.pageLabel.alpha = 0.2
            }, completion: nil)
        }
        
        // MARK: - Image loading
        
        public enum ImageLoadState {
            case notLoaded
            case loading
            case loaded
            case failed
        }
        
        fileprivate(set) var imageLoadState: ImageLoadState = .notLoaded
        fileprivate(set) var zoomImageLoadState: ImageLoadState = .notLoaded
        
        fileprivate func startLoadingViewImage(fromURL imageURL: URL) {
            
            imageLoadState = .loading

            // load the image from the url
            imageLoader?.loadImage(in: imageView, url: imageURL, transition: (fadeDuration: 0.1, evenWhenCached: false)) { [weak self] (result, url) in
                guard let s = self else { return }

                switch result {
                case let .success((image, fromCache)):
                    guard image.size.width > 0 && image.size.height > 0 else { return }
                    
                    s.imageLoadState = .loaded
                    s.delegate?.didFinishLoading(viewImage: url, fromCache: fromCache, in: s)
                case .failure(let error):
                    
                    if (error as? ImageLoaderError)?.isCancellationError == true {
                        // image load cancelled
                        s.imageLoadState = .notLoaded
                    } else {
                        
                        // TODO: handle failed image load
                        // tell delegate? show error? retry?
                        // maybe cache failed image urls to re-fail quickly?
                        TjekLogger.warning("[TjekSDK] ViewImage load failed (page: \(s.pageIndex))'\(error.localizedDescription)' (\((error as NSError).code)")
                        
                        s.imageLoadState = .failed
                    }
                }
            }
        }
        
        fileprivate func startLoadingZoomImage(fromURL zoomImageURL: URL) {
            
            zoomImageLoadState = .loading
            zoomImageView.image = nil
            zoomImageView.isHidden = false

            imageLoader?.loadImage(in: zoomImageView, url: zoomImageURL, transition: (fadeDuration: 0.3, evenWhenCached: true)) { [weak self] (result, url) in
                guard let s = self else { return }

                switch result {
                case let .success((_, fromCache)):
                    s.zoomImageLoadState = .loaded
                    s.delegate?.didFinishLoading(zoomImage: url, fromCache: fromCache, in: s)

                case .failure(let error):
                    s.zoomImageView.isHidden = true

                    if (error as? ImageLoaderError)?.isCancellationError == true {
                        s.zoomImageLoadState = .notLoaded // image load cancelled
                    } else {
                        // TODO: handle failed image load
                        // tell delegate? show error? retry?
                        // maybe cache failed image urls to re-fail quickly?
                        TjekLogger.warning("[TjekSDK] ZoomImage load failed (page: \(s.pageIndex))'\(error.localizedDescription)' (\((error as NSError).code)")
                        
                        s.zoomImageLoadState = .failed
                    }
                }
            }
        }
        
        func clearZoomImage(animated: Bool) {
            imageLoader?.cancelImageLoad(for: zoomImageView)
            zoomImageLoadState = .notLoaded
            
            if animated {
                UIView.transition(with: zoomImageView, duration: 0.3, options: [.transitionCrossDissolve], animations: { [weak self] in
                    self?.zoomImageView.image = nil
                    self?.zoomImageView.isHidden = true
                    }, completion: nil)
            } else {
                zoomImageView.image = nil
                zoomImageView.isHidden = true
            }
        }
    }
}
