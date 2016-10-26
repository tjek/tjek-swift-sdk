//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

import Verso
import Kingfisher


public protocol PagedPublicationPageViewDelegate : class {
    
    func didConfigure(pageView:PagedPublicationPageView, with viewModel:PagedPublicationPageViewModelProtocol)
    
    func didFinishLoading(viewImage imageURL:URL, fromCache:Bool, in pageView:PagedPublicationPageView)
    func didFinishLoading(zoomImage imageURL:URL, fromCache:Bool, in pageView:PagedPublicationPageView)
    
}

/// Make delegate methods optional
extension PagedPublicationPageViewDelegate {
    public func didConfigure(pageView:PagedPublicationPageView, with viewModel:PagedPublicationPageViewModelProtocol) {}
    public func didFinishLoading(viewImage imageURL:URL, fromCache:Bool, in pageView:PagedPublicationPageView) {}
    public func didFinishLoading(zoomImage imageURL:URL, fromCache:Bool, in pageView:PagedPublicationPageView) {}
}


open class LabelledVersoPageView : VersoPageView {
    
    public required init(frame: CGRect) {
        super.init(frame: frame)
        
        isUserInteractionEnabled = false
        
        // add subviews
        addSubview(pageLabel)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1.0)
        
        // must be started on non-main run loop to avoid interfering with scrolling
        self.perform(#selector(startPulsingNumberAnimation), with: nil, afterDelay:0, inModes: [RunLoopMode.commonModes])
    }
    
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    @objc
    fileprivate func startPulsingNumberAnimation() {
        UIView.animate(withDuration: 1, delay: 0, options: [.allowUserInteraction, .repeat, .autoreverse, .curveEaseIn], animations: {
            self.pageLabel.alpha = 0.2
            }, completion: nil)
    }
    
    open var pageLabel:UILabel = {
        
        let view = UILabel(frame: CGRect.zero)
        view.textColor = UIColor(white: 0, alpha: 0.8)
        view.textAlignment = .center
        view.baselineAdjustment = .alignCenters
        return view
    }()
    
    
    override open func layoutSubviews() {
        
        super.layoutSubviews()
        
        let fontSize = round(max(bounds.height, bounds.width) / 10)
        if pageLabel.font.pointSize != fontSize {
            pageLabel.font = UIFont.boldSystemFont(ofSize: fontSize)
        }
        
        pageLabel.frame = bounds
    }
    
}


open class PagedPublicationPageView : LabelledVersoPageView, UIGestureRecognizerDelegate {

    public enum ImageLoadState {
        case notLoaded
        case loading
        case loaded
        case failed
    }
    
    public required init(frame: CGRect) {
        super.init(frame: frame)
        
        // listen for memory warnings and clear the zoomimage
        NotificationCenter.default.addObserver(self, selector: #selector(PagedPublicationPageView.memoryWarningNotification(_:)), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
        
        
        // add subviews
        addSubview(imageView)
        addSubview(zoomImageView)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)
    }
    
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    
    
    
    
    // MARK: - Public
    
    weak open var delegate:PagedPublicationPageViewDelegate?
    
    open fileprivate(set) var imageLoadState:ImageLoadState = .notLoaded
    open fileprivate(set) var zoomImageLoadState:ImageLoadState = .notLoaded
    
    
    open func startLoadingZoomImageFromURL(_ zoomImageURL:URL) {
        
        zoomImageLoadState = .loading
        zoomImageView.image = nil
        zoomImageView.isHidden = false
        zoomImageView.kf.setImage(with: zoomImageURL, placeholder: nil, options: [.transition(.fade(0.3)), .forceTransition], progressBlock: nil) {  [weak self] (image, error, cacheType, url) in
            guard self != nil else {
                return
            }
            
            if image != nil {
                
                self!.zoomImageLoadState = .loaded
                
                self!.delegate?.didFinishLoading(zoomImage:zoomImageURL, fromCache:cacheType != .none, in:self!)
            }
            else {
                self!.zoomImageView.isHidden = true
                
                if let errorCode = error?.code, errorCode == NSURLErrorCancelled {
                    self!.zoomImageLoadState = .notLoaded
                    return // image load cancelled
                }
                
                // TODO: handle failed image load
                // tell delegate? show error? retry?
                // maybe cache failed image urls to re-fail quickly?
                self!.zoomImageLoadState = .failed
            }
        }
    }
    
    open func startLoadingImageFromURL(_ imageURL:URL) {
        
        imageLoadState = .loading
        
        // load the image from the url
        // TODO: allow for non-AlamoFire image loader
        // TODO: move image-loading to Publication?
        imageView.kf.setImage(with: imageURL, placeholder: nil, options: [.transition(.fade(0.1))], progressBlock: nil) {  [weak self] (image, error, cacheType, url) in
            guard self != nil else {
                return
            }
            
            if let newImage = image {
                if newImage.size.width > 0 && newImage.size.height > 0 {
                    
                    let newAspectRatio = newImage.size.width / newImage.size.height
                    
                    if newAspectRatio != self!.aspectRatio {
                        self!.aspectRatio = newAspectRatio
                        
                        // TODO: this will only affect future uses of this page. Somehow trigger a re-layout from the verso. Maybe in the delegate?
                    }
                }
                
                self!.imageLoadState = .loaded
                
                self!.delegate?.didFinishLoading(viewImage:imageURL, fromCache:cacheType != .none, in:self!)
            }
            else {
                
                if let errorCode = error?.code, errorCode == NSURLErrorCancelled {
                    self!.imageLoadState = .notLoaded
                    return // image load cancelled
                }
                
                // TODO: handle failed image load
                // tell delegate? show error? retry?
                // maybe cache failed image urls to re-fail quickly?
                print("image load failed", error?.localizedDescription ?? "", error?.code ?? "")
                
                self!.imageLoadState = .failed
            }
        }
    }
    
    open func clearZoomImage(animated:Bool) {
        
        zoomImageView.kf.cancelDownloadTask()
        zoomImageLoadState = .notLoaded
        
        if animated {
            UIView.transition(with: zoomImageView, duration: 0.3, options: [.transitionCrossDissolve], animations: { [weak self] in
                self?.zoomImageView.image = nil
                self?.zoomImageView.isHidden = true
                }, completion: nil)
        }
        else {
            zoomImageView.image = nil
            zoomImageView.isHidden = true
        }
    }
    
    open func configure(_ viewModel: PagedPublicationPageViewModelProtocol, publicationAspectRatio:CGFloat, darkBG:Bool) {
        
        reset()
        
        aspectRatio = viewModel.aspectRatio > 0 ? viewModel.aspectRatio : (publicationAspectRatio > 0 ? publicationAspectRatio : 1)
        
        
        pageLabel.text = viewModel.pageTitle
        pageLabel.textColor = darkBG ? UIColor.white : UIColor(white: 0, alpha: 0.7)
        
        backgroundColor = darkBG ? UIColor(white: 1, alpha: 0.1) : UIColor(white: 0.8, alpha: 0.15)
        
        if let imageURL = viewModel.viewImageURL {
            startLoadingImageFromURL(imageURL)
        }
        
        delegate?.didConfigure(pageView: self, with: viewModel)
    }

    
    
    // MARK: - Private
    
    fileprivate var aspectRatio:CGFloat = 0

    fileprivate func reset() {
        
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        imageLoadState = .notLoaded
        
        zoomImageView.kf.cancelDownloadTask()
        zoomImageView.image = nil
        zoomImageView.isHidden = true
        zoomImageLoadState = .notLoaded
        
        pageLabel.text = nil
        aspectRatio = 0
    }
    
    
    
    
    // MARK: - Subviews
    
    fileprivate var imageView:UIImageView = {
        let view = UIImageView(frame: CGRect.zero)
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentMode = .scaleAspectFit
        
        return view
    }()
    
    fileprivate var zoomImageView:UIImageView = {
        let view = UIImageView(frame: CGRect.zero)
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentMode = .scaleAspectFit
        
        return view
    }()
    
    
    
    
    // MARK: - UIView subclass
    
    // size based on aspect ratio
    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        guard size.width > 0 && size.height > 0 else {
            return size
        }
        
        var newSize = size
        
        let containerAspectRatio = size.width / size.height
        
        if aspectRatio < containerAspectRatio {
            newSize.width = newSize.height * aspectRatio
        }
        else if aspectRatio > containerAspectRatio {
            newSize.height = newSize.width / aspectRatio
        }
        
        return newSize
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        imageView.frame = bounds
        zoomImageView.frame = bounds
    }
    
    
    
    // MARK: - Notifications
    
    func memoryWarningNotification(_ notification:Notification) {
        clearZoomImage(animated:true)
    }
}
