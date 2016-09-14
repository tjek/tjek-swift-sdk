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
import AlamofireImage


@objc
public protocol PagedPublicationPageViewDelegate : class {
    
    optional func didConfigurePagedPublicationPage(pageView:PagedPublicationPageView, viewModel:PagedPublicationPageViewModelProtocol)
    
    optional func didLoadPagedPublicationPageImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool)
    optional func didLoadPagedPublicationPageZoomImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool)
    
}

public class LabelledVersoPageView : VersoPageView {
    
    public required init(frame: CGRect) {
        super.init(frame: frame)
        
        // add subviews
        addSubview(pageLabel)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1.0)
    }
    
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    
    public var pageLabel:UILabel = {
        
        let view = UILabel(frame: CGRectZero)
        view.font = UIFont.boldSystemFontOfSize(24)
        view.textColor = UIColor(white: 0, alpha: 0.8)
        view.textAlignment = .Center
        
        return view
    }()
    
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        // position label in the middle
        var labelFrame = pageLabel.frame
        labelFrame.size = pageLabel.sizeThatFits(frame.size)
        labelFrame.origin = CGPoint(x:round(bounds.size.width/2 - labelFrame.size.width/2), y:round(bounds.size.height/2 - labelFrame.size.height/2))
        
        pageLabel.frame = labelFrame
    }
    
}


public class PagedPublicationPageView : LabelledVersoPageView, UIGestureRecognizerDelegate {

    public enum ImageLoadState {
        case NotLoaded
        case Loading
        case Loaded
        case Failed
    }
    
    public required init(frame: CGRect) {
        super.init(frame: frame)
        
        // listen for memory warnings and clear the zoomimage
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PagedPublicationPageView.memoryWarningNotification(_:)), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        
        
        // add subviews
        addSubview(imageView)
        addSubview(zoomImageView)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)
    }
    
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    
    
    
    
    // MARK: - Public
    
    weak public var delegate:PagedPublicationPageViewDelegate?
    
    public private(set) var imageLoadState:ImageLoadState = .NotLoaded
    public private(set) var zoomImageLoadState:ImageLoadState = .NotLoaded
    
    
    public func startLoadingZoomImageFromURL(zoomImageURL:NSURL) {
        
        zoomImageLoadState = .Loading
        zoomImageView.image = nil
        zoomImageView.hidden = false
        
        zoomImageView.af_setImageWithURL(zoomImageURL, imageTransition: .CrossDissolve(0.3), runImageTransitionIfCached: true) { [weak self] response in
            guard self != nil else {
                return
            }
            
            if response.result.isSuccess {
                
                self!.zoomImageLoadState = .Loaded
                
                self!.delegate?.didLoadPagedPublicationPageZoomImage?(self!, imageURL:zoomImageURL, fromCache:(response.response == nil))
            }
            else {
                self!.zoomImageView.hidden = true
                
                if let error = response.result.error {
                    if error.code == NSURLErrorCancelled {
                        self!.zoomImageLoadState = .NotLoaded
                        return // image load cancelled
                    }
                }
                // TODO: handle failed image load
                // tell delegate? show error? retry?
                // maybe cache failed image urls to re-fail quickly?
                self!.zoomImageLoadState = .Failed
            }
        }
    }
    
    public func startLoadingImageFromURL(imageURL:NSURL) {
        
        imageLoadState = .Loading
        
        // load the image from the url
        // TODO: allow for non-AlamoFire image loader
        // TODO: move image-loading to Publication?
        imageView.af_setImageWithURL(imageURL, imageTransition: .CrossDissolve(0.1), runImageTransitionIfCached: false) { [weak self] response in
            guard self != nil else {
                return
            }
            
            if response.result.isSuccess {
                // Update the aspect ratio based on the actual loaded image.
                if let image = response.result.value
                    where image.size.width > 0 && image.size.height > 0 {
                    
                    let newAspectRatio = image.size.width / image.size.height
                    
                    if newAspectRatio != self!.aspectRatio {
                        self!.aspectRatio = newAspectRatio
                        // TODO: this will only affect future uses of this page. Somehow trigger a re-layout from the verso. Maybe in the delegate?
                    }
                }
                
                self!.imageLoadState = .Loaded
                
                self!.delegate?.didLoadPagedPublicationPageImage?(self!, imageURL:imageURL, fromCache:(response.response == nil))
            }
            else {
                
                if let error = response.result.error {
                    if error.code == NSURLErrorCancelled {
                        self!.imageLoadState = .NotLoaded
                        return // image load cancelled
                    }
                }
                // TODO: handle failed image load
                // tell delegate? show error? retry?
                // maybe cache failed image urls to re-fail quickly?
                print("image load failed", response.result.error?.localizedDescription, response.result.error?.code)
                
                self!.imageLoadState = .Failed
            }
        }
    }
    
    public func clearZoomImage(animated animated:Bool) {
        zoomImageView.af_cancelImageRequest()
        zoomImageLoadState = .NotLoaded
        
        if animated {
            UIView.transitionWithView(zoomImageView, duration: 0.3, options: [.TransitionCrossDissolve], animations: { [weak self] in
                self?.zoomImageView.image = nil
                self?.zoomImageView.hidden = true
                }, completion: nil)
        }
        else {
            zoomImageView.image = nil
            zoomImageView.hidden = true
        }
    }
    
    public func configure(viewModel: PagedPublicationPageViewModelProtocol) {
        
        reset()
        
        // cancel any previous image loads
        
        aspectRatio = CGFloat(viewModel.aspectRatio)
        
        pageLabel.text = viewModel.pageTitle
        
        
        if let imageURL = viewModel.defaultImageURL {
            startLoadingImageFromURL(imageURL)
        }
        
        delegate?.didConfigurePagedPublicationPage?(self, viewModel: viewModel)
    }

    
    
    // MARK: - Private
    
    private var aspectRatio:CGFloat = 0

    private func reset() {
        imageView.af_cancelImageRequest()
        imageView.image = nil
        imageLoadState = .NotLoaded
        
        zoomImageView.af_cancelImageRequest()
        zoomImageView.image = nil
        zoomImageView.hidden = true
        zoomImageLoadState = .NotLoaded
        
        pageLabel.text = nil
        aspectRatio = 0
    }
    
    
    
    
    // MARK: - Subviews
    
    private var imageView:UIImageView = {
        let view = UIImageView(frame: CGRectZero)
        
        view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.contentMode = .ScaleAspectFit
        
        return view
    }()
    
    private var zoomImageView:UIImageView = {
        let view = UIImageView(frame: CGRectZero)
        
        view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.contentMode = .ScaleAspectFit
        
        return view
    }()
    
    
    
    
    // MARK: - UIView subclass
    
    // size based on aspect ratio
    override public func sizeThatFits(size: CGSize) -> CGSize {
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
    
    override public func layoutSubviews() {
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
    
    func memoryWarningNotification(notification:NSNotification) {
        clearZoomImage(animated:true)
    }
}
