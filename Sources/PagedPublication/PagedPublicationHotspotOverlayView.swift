//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit



protocol HotspotOverlayViewDelegate : class {
    
    func didTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint)
    func didLongPressHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint)
    func didDoubleTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint)

}

extension HotspotOverlayViewDelegate {
    
    func didTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {}
    func didLongPressHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {}
    func didDoubleTapHotspot(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {}
}



extension PagedPublicationView {
    
    class HotspotView : UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            backgroundColor = UIColor(white: 1, alpha: 0.5)
            layer.borderWidth = 1.0 / max(UIScreen.main.scale, 0)
            layer.borderColor = UIColor(white: 0, alpha: 0.4).cgColor
            layer.cornerRadius = 4
        }
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class HotspotOverlayView : UIView, UIGestureRecognizerDelegate {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            _initializeGestureRecognizers()
        }
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            for (index, hotspot) in hotspotModels.enumerated() {
                if let hotspotView = hotspotViews[sgn_safe:index], let hotspotFrame = _frameForHotspot(hotspot) {
                    hotspotView.frame = hotspotFrame
                }
            }
        }

        weak var delegate:HotspotOverlayViewDelegate?
        
        fileprivate func _getTargetPage(forGesture gesture:UIGestureRecognizer) -> (index:Int, location:CGPoint)? {
            
            // find the page that the gesture occurred in
            var possibleTargetPage:(index:Int, location:CGPoint)?
            for (pageIndex, pageView) in pageViews {
                let pageLocation = gesture.location(in: pageView)
                if pageView.bounds.isEmpty == false && pageView.bounds.contains(pageLocation) {
                    possibleTargetPage = (index:pageIndex, location:CGPoint(x:pageLocation.x/pageView.bounds.size.width, y:pageLocation.y/pageView.bounds.size.height))
                    break
                }
            }
            return possibleTargetPage
        }
        
        fileprivate func _getHotspotsAtPoint(_ location:CGPoint) -> (views:[UIView], models:[PagedPublicationHotspotViewModelProtocol]) {
            
            var views:[UIView] = []
            var models:[PagedPublicationHotspotViewModelProtocol] = []
            
            
            // get only the hotspots & views that were touched
            for (index, hotspotView) in hotspotViews.enumerated() {
                if hotspotView.frame.contains(location) {
                    let hotspotModel = hotspotModels[index]
                    
                    views.append(hotspotView)
                    models.append(hotspotModel)
                }
            }
            return (views:views, models:models)
        }
        
        
        // MARK: - Gestures
        
        var touchGesture:UILongPressGestureRecognizer?
        var tapGesture:UITapGestureRecognizer?
        var longPressGesture:UILongPressGestureRecognizer?
        var doubleTapGesture:UITapGestureRecognizer?

        fileprivate func _initializeGestureRecognizers() {
            
            touchGesture = UILongPressGestureRecognizer(target: self, action:#selector(HotspotOverlayView.didTouch(_:)))
            touchGesture!.minimumPressDuration = 0.15
            touchGesture!.delegate = self
            touchGesture!.cancelsTouchesInView = false
            
            tapGesture = UITapGestureRecognizer(target: self, action: #selector(HotspotOverlayView.didTap(_:)))
            tapGesture!.delegate = self
            tapGesture!.cancelsTouchesInView = false

            longPressGesture = UILongPressGestureRecognizer(target: self, action:#selector(HotspotOverlayView.didLongPress(_:)))
            longPressGesture!.delegate = self
            
            doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(HotspotOverlayView.didDoubleTap(_:)))
            doubleTapGesture!.numberOfTapsRequired = 2
            doubleTapGesture!.delegate = self
            
            
            tapGesture?.require(toFail: longPressGesture!)
            
            
            addGestureRecognizer(longPressGesture!)
            addGestureRecognizer(tapGesture!)
            addGestureRecognizer(touchGesture!)
            addGestureRecognizer(doubleTapGesture!)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer == tapGesture {
                return gestureRecognizer == touchGesture
            }
            else if gestureRecognizer == touchGesture {
                return true
            }
            else if gestureRecognizer == longPressGesture {
                return otherGestureRecognizer != tapGesture
            }
            else if gestureRecognizer == doubleTapGesture {
                return true
            }
            else {
                return false
            }
        }
        
        func didTouch(_ touch:UILongPressGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else {
                return
            }
            
            if touch.state == .began {
                
                let location = touch.location(in: self)
                let hotspots = _getHotspotsAtPoint(location)
                
                // highlight the hotspots that were touched
                UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                    for hotspotView in hotspots.views {
                        hotspotView.alpha = 0.5
                    }
                    }, completion: nil)

            } else if touch.state == .ended || touch.state == .failed  || touch.state == .cancelled {

                // fade out all hotspot views when touch finishes
                UIView.animate(withDuration: 0.2, delay: 0.0, options:[.beginFromCurrentState, .allowUserInteraction], animations: { [weak self] in
                    guard self != nil else { return }
                    
                    for view in self!.hotspotViews {
                        view.alpha = 0.0
                    }
                    }, completion: nil)

            }
        }
        
        func didTap(_ tap:UITapGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else {
                return
            }
            
            guard let targetPage = _getTargetPage(forGesture:tap) else {
                return
            }

            let overlayLocation = tap.location(in: self)
            let hotspots = _getHotspotsAtPoint(overlayLocation)

            delegate?.didTapHotspot(overlay:self, hotspots: hotspots.models, hotspotViews: hotspots.views, locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
        }
        
        func didLongPress(_ press:UILongPressGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else {
                return
            }

            if press.state == .began {
                
                let overlayLocation = press.location(in: self)
                let hotspots = _getHotspotsAtPoint(overlayLocation)
                
                // bounce the views
                for hotspotView in hotspots.views {
                    UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState], animations: {
                        
                        hotspotView.alpha = 1.0
                        hotspotView.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.1)
                        
                    }) { (finished) in
                        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.7, options: [.beginFromCurrentState], animations: {
                            hotspotView.layer.transform = CATransform3DIdentity
                            hotspotView.alpha = 0.5
                        }) { (finished) in
                            hotspotView.alpha = 0.0
                        }
                    }
                }
                
                
                
                guard let targetPage = _getTargetPage(forGesture:press) else {
                    return
                }

                delegate?.didLongPressHotspot(overlay:self, hotspots: hotspots.models, hotspotViews: hotspots.views, locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
            }
        }
        
        func didDoubleTap(_ doubleTap:UITapGestureRecognizer) {
            
            if doubleTap.state == .ended {
                
                guard let targetPage = _getTargetPage(forGesture:doubleTap) else {
                    return
                }
                
                let overlayLocation = doubleTap.location(in: self)                
                let hotspots = _getHotspotsAtPoint(overlayLocation)
                
                delegate?.didDoubleTapHotspot(overlay:self, hotspots: hotspots.models, hotspotViews: hotspots.views, locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
                
            }
        }
        
        
        
        // MARK: Hotspot views
        
        
        fileprivate var hotspotModels:[PagedPublicationHotspotViewModelProtocol] = []
        fileprivate var hotspotViews:[UIView] = []
        fileprivate var pageViews:[Int:UIView] = [:]
        
        func updateWithHotspots(_ hotspots:[PagedPublicationHotspotViewModelProtocol], pageFrames:[Int:CGRect]) {
            
            // update pageViews (simply used for their frames & autoresizing powers)
            for (_, pageView) in pageViews {
                pageView.removeFromSuperview()
            }
            var newPageViews:[Int:UIView] = [:]
            for (pageIndex, pageFrame) in pageFrames {
                let pageView = UIView(frame:pageFrame)
                pageView.isHidden = true
                pageView.isUserInteractionEnabled = false
                pageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(pageView)
                newPageViews[pageIndex] = pageView
            }
            pageViews = newPageViews

            
            
            let minSize = CGSize(width: min(bounds.size.width * 0.02, 20), height: min(bounds.size.height * 0.02, 20))
            
            for hotspotView in hotspotViews {
                hotspotView.removeFromSuperview()
            }
            var newHotspotModels:[PagedPublicationHotspotViewModelProtocol] = []
            var newHotspotViews:[UIView] = []
            for hotspot in hotspots {
                if let hotspotFrame = _frameForHotspot(hotspot), hotspotFrame.isEmpty == false && hotspotFrame.width > minSize.width && hotspotFrame.height > minSize.height {
                    
                    let hotspotView = HotspotView(frame: hotspotFrame)
                    hotspotView.alpha = 0
                    hotspotView.isUserInteractionEnabled = false
                    
                    addSubview(hotspotView)
                    
                    newHotspotViews.append(hotspotView)
                    newHotspotModels.append(hotspot)
                }
            }
            hotspotViews = newHotspotViews
            hotspotModels = newHotspotModels
        }
        
        
        
        fileprivate func _frameForHotspot(_ hotspot:PagedPublicationHotspotViewModelProtocol) -> CGRect? {
            
            var combinedHotspotFrame:CGRect?
            
            let hotspotPageIndexes = hotspot.getPageIndexes()
            for hotspotPageIndex in hotspotPageIndexes {
                guard let pageView = pageViews[hotspotPageIndex] else {
                    continue
                }
                
                let hotspotLocation = hotspot.getLocationForPageIndex(hotspotPageIndex)
                guard hotspotLocation.isEmpty == false else {
                    continue
                }
                
                let pageFrame = pageView.frame
                
                let hotspotFrame = CGRect(x: pageFrame.origin.x + (hotspotLocation.origin.x * pageFrame.width),
                                          y: pageFrame.origin.y + (hotspotLocation.origin.y * pageFrame.height),
                                          width: hotspotLocation.width * pageFrame.width,
                                          height: hotspotLocation.height * pageFrame.height)
                
                combinedHotspotFrame = combinedHotspotFrame?.union(hotspotFrame) ?? hotspotFrame
            }
            
            return combinedHotspotFrame
        }
        
    }
}
