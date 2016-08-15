//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


import AlamofireImage



public protocol PDFPublicationPageViewModelProtocol {
    
    var pageIndex:UInt { get }
    
    var pageTitle:String? { get }
    
    var aspectRatio:Double { get }
    
    var defaultImageURL:NSURL? { get }

    var zoomImageURL:NSURL? { get }
    
    var hotspots:[PDFPublicationHotspotViewModelProtocol]? { get }
}


public protocol PDFPublicationPageContentsViewDelegate : class {
    
    func didConfigurePDFPageContents(pageIndex:UInt, viewModel:PDFPublicationPageViewModelProtocol)
    
    func didLoadPDFPageContentsImage(pageIndex:UInt, imageURL:NSURL, fromCache:Bool)
    
    // did zoom?
}


public class PDFPublicationPageContentsView : UIView {

    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(pageLabel)
        
        imageView.frame = frame
        addSubview(imageView)
        
        
        backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.2)
    }
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    public private(set) var isImageLoaded:Bool = false
    
    var aspectRatio:CGFloat = 0
    
    
    
    
    weak public var delegate:PDFPublicationPageContentsViewDelegate?
    
    
    public typealias ViewModelType = PDFPublicationPageViewModelProtocol
    
    public func configure(viewModel:ViewModelType) {
        
        reset()
        
        // cancel any previous image loads
        
        aspectRatio = CGFloat(viewModel.aspectRatio)
        
        pageLabel.text = viewModel.pageTitle
        
        let pageIndex = viewModel.pageIndex
        
        
        
        
        delegate?.didConfigurePDFPageContents(pageIndex, viewModel: viewModel)
        
        if let imageURL = viewModel.defaultImageURL {
            
            // load the image from the url
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
                            
                            // somewhat hacky way of invalidating the parent cell's layout
                            self!.superview?.superview?.setNeedsLayout()
                        }
                    }
                    
                    self!.isImageLoaded = true
                    
                    self!.delegate?.didLoadPDFPageContentsImage(pageIndex, imageURL:imageURL, fromCache:(response.response == nil))
                }
                else {
                    
                    if let error = response.result.error {
                        if error.code == NSURLErrorCancelled {
                            return // image load cancelled
                        }
                    }
                    // tell delegate? show error? retry?
                    print("image load failed", response.result.error?.localizedDescription, response.result.error?.code)
                }
            }
        }
        
        setNeedsLayout()
    }

    
    
    public func reset() {
        imageView.image = nil
        pageLabel.text = nil
        aspectRatio = 0
        isImageLoaded = false
    }
    
    
    // MARK: Views
    
    var pageLabel:UILabel = {
        
        let view = UILabel(frame: CGRectZero)
        view.font = UIFont.systemFontOfSize(UIFont.systemFontSize())
        view.textAlignment = .Center
        
        return view
    }()
    
    var imageView:UIImageView = {
        let view = UIImageView(frame: CGRectZero)
        
        view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.contentMode = .ScaleAspectFit

        // TODO: use a custom image loader
        
        return view
    }()
    
    
    // MARK: UIView subclass
    
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
    }
}








/// A subclass that implements the VersoPageCell with the PDFPublication contents view

// TODO: do this in an extension?
public class PDFPublicationPageCell : VersoPageCell<PDFPublicationPageContentsView> {
    
    public func configure(viewModel: PDFPublicationPageViewModelProtocol) {
        contentView.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.1)
        pageContentsView?.configure(viewModel)
    }
    
}


