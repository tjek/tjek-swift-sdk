//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

protocol VersoZoomingReusableViewDelegate : class {
    func updateZoomProperties(scale:CGFloat, offset:CGPoint)
}

class VersoZoomingReusableViewLayoutAttributes : UICollectionViewLayoutAttributes {
    weak var zoomDelegate:VersoZoomingReusableViewDelegate? = nil
    
    deinit {
        zoomDelegate = nil
    }
}


class VersoZoomingReusableView : UICollectionReusableView, UIScrollViewDelegate {
    
    static let kind = "VersoZoomingReusableView"
    
    var zoomView:UIScrollView?
    var zoomViewContents:UIView?
    
    weak var delegate:VersoZoomingReusableViewDelegate? = nil {
        didSet {
            refreshZoomViewProperties()
        }
    }
    
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        _sharedInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _sharedInit()
    }
    
    func _sharedInit() {
        
        zoomView = UIScrollView(frame:bounds)
        zoomView!.delegate = self
        zoomView!.maximumZoomScale = 4.0
        zoomView!.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        
        addSubview(zoomView!)
        
        zoomViewContents = UIView(frame:zoomView!.bounds)
        zoomViewContents!.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        zoomView!.addSubview(zoomViewContents!)
        
        debugify(true)
    }
    
    deinit {
        delegate = nil
    }
    
    
    // called whenever there is a displayLink tick in the zoom view
    func refreshZoomViewProperties() {
        
        if let zoomLayer = zoomView?.layer.presentationLayer() as? CALayer,
            let zoomContentsLayer = zoomViewContents?.layer.presentationLayer() as? CALayer {
            
            
            let offset = zoomLayer.bounds.origin
            let scale = zoomContentsLayer.transform.m11
            
            delegate?.updateZoomProperties(scale, offset: offset)            
         
        }
    }
    
    override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes) {
        super.applyLayoutAttributes(layoutAttributes)
        
        if let zoomDelegate = (layoutAttributes as? VersoZoomingReusableViewLayoutAttributes)?.zoomDelegate {
            delegate = zoomDelegate
        }
    }
    
    
    
    func debugify(debugify:Bool) {
        for view in zoomViewContents!.subviews {
            view.removeFromSuperview()
        }
        
        if (debugify) {
            clipsToBounds = false
            zoomView?.clipsToBounds = false
    
            
            let debugView = UIView(frame:CGRect(x: 0, y: 0, width: 50, height: 50))
            debugView.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin, .FlexibleTopMargin, .FlexibleBottomMargin]
            
            debugView.backgroundColor = UIColor.greenColor()
            debugView.center = zoomViewContents!.center
            
            zoomViewContents?.addSubview(debugView)
            
    
            backgroundColor = UIColor.redColor()
            zoomViewContents?.backgroundColor = UIColor.blueColor()
    
            alpha = 0.3
            zoomViewContents?.alpha = 0.8
        } else {
            clipsToBounds = true
            zoomView?.clipsToBounds = true
    
            zoomViewContents?.backgroundColor = nil
            backgroundColor = nil
    
            zoomViewContents?.alpha = 0
            alpha = 0
        }
    }

    
    
    
    // MARK: - Scroll View Delegate
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return zoomViewContents
    }
    
    func scrollViewWillBeginZooming(scrollView: UIScrollView, withView view: UIView?) {
        startDisplayLinkIfNeeded()
    }
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        startDisplayLinkIfNeeded()
    }
    func scrollViewDidZoom(scrollView: UIScrollView) {
        refreshZoomViewProperties()
    }
    func scrollViewDidScroll(scrollView: UIScrollView) {
        refreshZoomViewProperties()
    }
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        refreshZoomViewProperties()
        stopDisplayLink()
    }
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate && !scrollView.zoomBouncing {
            refreshZoomViewProperties()
            stopDisplayLink()
        }
    }
    func scrollViewDidEndZooming(scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        if !scrollView.zoomBouncing {
            refreshZoomViewProperties()
            stopDisplayLink()
        }
    }
    
    
    // MARK: - Display Link
    
    var _displayLink:CADisplayLink?
    
    func startDisplayLinkIfNeeded() {
        if _displayLink == nil {
            _displayLink = CADisplayLink(target: self, selector: #selector(VersoZoomingReusableView.displayLinkTick))
            _displayLink?.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        }
    }
    
    func stopDisplayLink() {
        _displayLink?.invalidate()
        _displayLink = nil
    }
    
    func displayLinkTick() {
        refreshZoomViewProperties()
    }
}
