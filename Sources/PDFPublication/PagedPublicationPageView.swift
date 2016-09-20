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


@objc
public protocol PagedPublicationPageViewDelegate : class {
    
    @objc optional func didConfigure(_ pageView:PagedPublicationPageView, viewModel:PagedPublicationPageViewModelProtocol)
    
    @objc optional func didFinishLoadingImage(_ pageView:PagedPublicationPageView, imageURL:URL, fromCache:Bool)
    @objc optional func didFinishLoadingZoomImage(_ pageView:PagedPublicationPageView, imageURL:URL, fromCache:Bool)
    
}

open class LabelledVersoPageView : VersoPageView {
    
    public required init(frame: CGRect) {
        super.init(frame: frame)
        
        // add subviews
        addSubview(pageLabel)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1.0)
    }
    
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    
    open var pageLabel:UILabel = {
        
        let view = UILabel(frame: CGRect.zero)
        view.font = UIFont.boldSystemFont(ofSize: 24)
        view.textColor = UIColor(white: 0, alpha: 0.8)
        view.textAlignment = .center
        
        return view
    }()
    
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        // position label in the middle
        var labelFrame = pageLabel.frame
        labelFrame.size = pageLabel.sizeThatFits(frame.size)
        labelFrame.origin = CGPoint(x:round(bounds.size.width/2 - labelFrame.size.width/2), y:round(bounds.size.height/2 - labelFrame.size.height/2))
        
        pageLabel.frame = labelFrame
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
        zoomImageView.kf_setImage(with: zoomImageURL, placeholder: nil, options: [.transition(.fade(0.3)), .forceTransition], progressBlock: nil) {  [weak self] (image, error, cacheType, url) in
            guard self != nil else {
                return
            }
            
            if image != nil {
                
                self!.zoomImageLoadState = .loaded
                
                self!.delegate?.didFinishLoadingZoomImage?(self!, imageURL:zoomImageURL, fromCache:cacheType != .none)
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
        imageView.kf_setImage(with: imageURL, placeholder: nil, options: [.transition(.fade(0.1))], progressBlock: nil) {  [weak self] (image, error, cacheType, url) in
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
                
                self!.delegate?.didFinishLoadingImage?(self!, imageURL:imageURL, fromCache:cacheType != .none)
            }
            else {
                
                if let errorCode = error?.code, errorCode == NSURLErrorCancelled {
                    self!.imageLoadState = .notLoaded
                    return // image load cancelled
                }
                
                // TODO: handle failed image load
                // tell delegate? show error? retry?
                // maybe cache failed image urls to re-fail quickly?
                print("image load failed", error?.localizedDescription, error?.code)
                
                self!.imageLoadState = .failed
            }
        }
    }
    
    open func clearZoomImage(animated:Bool) {
        
        zoomImageView.kf_cancelDownloadTask()
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
    
    open func configure(_ viewModel: PagedPublicationPageViewModelProtocol) {
        
        reset()
        
        // cancel any previous image loads
        
        aspectRatio = CGFloat(viewModel.aspectRatio)
        
        pageLabel.text = viewModel.pageTitle
        
        
        if let imageURL = viewModel.defaultImageURL {
            startLoadingImageFromURL(imageURL as URL)
        }
        
        delegate?.didConfigure?(self, viewModel: viewModel)
    }

    
    
    // MARK: - Private
    
    fileprivate var aspectRatio:CGFloat = 0

    fileprivate func reset() {
        
        imageView.kf_cancelDownloadTask()
        imageView.image = nil
        imageLoadState = .notLoaded
        
        zoomImageView.kf_cancelDownloadTask()
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
        
        // position label in the middle
        var labelFrame = pageLabel.frame
        labelFrame.size = pageLabel.sizeThatFits(frame.size)
        labelFrame.origin = CGPoint(x:round(bounds.size.width/2 - labelFrame.size.width/2), y:round(bounds.size.height/2 - labelFrame.size.height/2))
        
        pageLabel.frame = labelFrame
        
        imageView.frame = bounds
        zoomImageView.frame = bounds
    }
    
    
    
    // MARK: - Notifications
    
    func memoryWarningNotification(_ notification:Notification) {
        clearZoomImage(animated:true)
    }
}
