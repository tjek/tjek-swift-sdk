//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


@objc
public protocol PagedPublicationHotspotViewModelProtocol {
    var data:AnyObject? { get }
    
    /// return CGRectNull if the hotspot isnt in that page
    func getLocationForPageIndex(pageIndex:Int)->CGRect
    
    func getPageIndexes()->NSIndexSet
}


@objc (SGNPagedPublicationHotspotViewModel)
public class PagedPublicationHotspotViewModel : NSObject, PagedPublicationHotspotViewModelProtocol {
    
    public var data:AnyObject? = nil // TODO: cast as Offer obj?
    
    public func getLocationForPageIndex(pageIndex:Int) -> CGRect {
        return pageLocations[pageIndex] ?? CGRectNull
    }
    public func getPageIndexes()->NSIndexSet {
        let pageIndexes = NSMutableIndexSet()
        for (pageIndex, _) in pageLocations {
            pageIndexes.addIndex(pageIndex)
        }
        return pageIndexes
    }
    
    
    private var pageLocations:[Int:CGRect]
    
    public init(pageLocations:[Int:CGRect], data:AnyObject? = nil) {
        self.pageLocations = pageLocations
        self.data = data
    }
}


protocol HotspotOverlayViewDelegate : class {
    
    func didTapHotspotOverlayView(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint)
    func didLongPressHotspotOverlayView(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint)
}

extension HotspotOverlayViewDelegate {
    
    func didTapHotspotOverlayView(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {}
    func didLongPressHotspotOverlayView(overlay:PagedPublicationView.HotspotOverlayView, hotspots:[PagedPublicationHotspotViewModelProtocol], hotspotViews:[UIView], locationInOverlay:CGPoint, pageIndex:Int, locationInPage:CGPoint) {}
}



extension PagedPublicationView {
    
    class HotspotView : UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            backgroundColor = UIColor(white: 1, alpha: 0.5)
            layer.borderWidth = 1.0 / max(UIScreen.mainScreen().scale, 0)
            layer.borderColor = UIColor(white: 0, alpha: 0.4).CGColor
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
            
            for (index, hotspot) in hotspotModels.enumerate() {
                if let hotspotView = hotspotViews[sgn_safe:index], let hotspotFrame = _frameForHotspot(hotspot) {
                    hotspotView.frame = hotspotFrame
                }
            }
        }

        weak var delegate:HotspotOverlayViewDelegate?
        
        
        private func _getHotspotsAtPoint(location:CGPoint) -> (views:[UIView], models:[PagedPublicationHotspotViewModelProtocol]) {
            
            var views:[UIView] = []
            var models:[PagedPublicationHotspotViewModelProtocol] = []
            
            
            // get only the hotspots & views that were touched
            for (index, hotspotView) in hotspotViews.enumerate() {
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
        
        private func _initializeGestureRecognizers() {
            
            touchGesture = UILongPressGestureRecognizer(target: self, action:#selector(HotspotOverlayView.didTouch(_:)))
            touchGesture!.minimumPressDuration = 0.01
            touchGesture!.delegate = self
            
            tapGesture = UITapGestureRecognizer(target: self, action: #selector(HotspotOverlayView.didTap(_:)))
            tapGesture!.delegate = self

            longPressGesture = UILongPressGestureRecognizer(target: self, action:#selector(HotspotOverlayView.didLongPress(_:)))
            longPressGesture!.delegate = self
            
            tapGesture?.requireGestureRecognizerToFail(longPressGesture!)
            
            addGestureRecognizer(longPressGesture!)
            addGestureRecognizer(tapGesture!)
            addGestureRecognizer(touchGesture!)
        }
        
        func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer == tapGesture {
                return gestureRecognizer != longPressGesture
            }
            else if gestureRecognizer == touchGesture {
                return true
            }
            else if gestureRecognizer == longPressGesture {
                return otherGestureRecognizer != tapGesture
            }
            else {
                return false
            }
        }

        
        
        func didTouch(touch:UILongPressGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else {
                return
            }
            
            if touch.state == .Began {
                
                let location = touch.locationInView(self)
                
                let hotspots = _getHotspotsAtPoint(location)
                
                // highlight the hotspots that were touched
                UIView.animateWithDuration(0.1, delay: 0, options: [.BeginFromCurrentState], animations: {
                    for hotspotView in hotspots.views {
                        hotspotView.alpha = 0.5
                    }
                    }, completion: nil)

            } else if touch.state == .Ended || touch.state == .Failed  || touch.state == .Cancelled {

                // fade out all hotspot views when touch finishes
                UIView.animateWithDuration(0.2, delay: 0.0, options:[.BeginFromCurrentState], animations: { [weak self] in
                    guard self != nil else { return }
                    
                    for view in self!.hotspotViews {
                        view.alpha = 0.0
                    }
                    }, completion: nil)

            }
        }
        
        func didTap(tap:UITapGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else {
                return
            }
            
            var possibleTargetPage:(index:Int, location:CGPoint)?
            for (pageIndex, pageView) in pageViews {
                let pageLocation = tap.locationInView(pageView)
                if pageView.bounds.isEmpty == false && pageView.bounds.contains(pageLocation) {
                    possibleTargetPage = (index:pageIndex, location:CGPoint(x:pageLocation.x/pageView.bounds.size.width, y:pageLocation.y/pageView.bounds.size.height))
                    break
                }
            }
            
            guard let targetPage = possibleTargetPage else {
                return
            }
            
            let overlayLocation = tap.locationInView(self)
            
            let hotspots = _getHotspotsAtPoint(overlayLocation)

            delegate?.didTapHotspotOverlayView(self, hotspots: hotspots.models, hotspotViews: hotspots.views, locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
        }
        
        func didLongPress(press:UILongPressGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else {
                return
            }
            
            let overlayLocation = press.locationInView(self)

            if press.state == .Began {
                let hotspots = _getHotspotsAtPoint(overlayLocation)
                
                // bounce the views
                for hotspotView in hotspots.views {
                    UIView.animateWithDuration(0.1, delay: 0, options: [.BeginFromCurrentState], animations: {
                        
                        hotspotView.alpha = 1.0
                        hotspotView.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.1)
                        
                    }) { (finished) in
                        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.7, options: [.BeginFromCurrentState], animations: {
                            hotspotView.layer.transform = CATransform3DIdentity
                            hotspotView.alpha = 0.5
                        }) { (finished) in
                            hotspotView.alpha = 0.0
                        }
                    }
                }
                
                
                
                var possibleTargetPage:(index:Int, location:CGPoint)?
                for (pageIndex, pageView) in pageViews {
                    let pageLocation = press.locationInView(pageView)
                    if pageView.bounds.isEmpty == false && pageView.bounds.contains(pageLocation) {
                        possibleTargetPage = (index:pageIndex, location:CGPoint(x:pageLocation.x/pageView.bounds.size.width, y:pageLocation.y/pageView.bounds.size.height))
                        break
                    }
                }
                
                guard let targetPage = possibleTargetPage else {
                    return
                }

                delegate?.didLongPressHotspotOverlayView(self, hotspots: hotspots.models, hotspotViews: hotspots.views, locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
            }
        }
        
        
        // MARK: Hotspot views
        
        
        private var hotspotModels:[PagedPublicationHotspotViewModel] = []
        private var hotspotViews:[UIView] = []
        private var pageViews:[Int:UIView] = [:]
        
        func updateWithHotspots(hotspots:[PagedPublicationHotspotViewModel], pageFrames:[Int:CGRect]) {
            
            // update pageViews (simply used for their frames & autoresizing powers)
            for (_, pageView) in pageViews {
                pageView.removeFromSuperview()
            }
            var newPageViews:[Int:UIView] = [:]
            for (pageIndex, pageFrame) in pageFrames {
                let pageView = UIView(frame:pageFrame)
                pageView.hidden = true
                pageView.userInteractionEnabled = false
                pageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
                addSubview(pageView)
                newPageViews[pageIndex] = pageView
            }
            pageViews = newPageViews

            
            
            let minSize = CGSize(width: min(bounds.size.width * 0.02, 20), height: min(bounds.size.height * 0.02, 20))
            
            for hotspotView in hotspotViews {
                hotspotView.removeFromSuperview()
            }
            var newHotspotModels:[PagedPublicationHotspotViewModel] = []
            var newHotspotViews:[UIView] = []
            for hotspot in hotspots {
                if let hotspotFrame = _frameForHotspot(hotspot)
                    where hotspotFrame.isEmpty == false && hotspotFrame.width > minSize.width && hotspotFrame.height > minSize.height {
                    
                    let hotspotView = HotspotView(frame: hotspotFrame)
                    hotspotView.alpha = 0
                    hotspotView.userInteractionEnabled = false
                    
                    addSubview(hotspotView)
                    
                    newHotspotViews.append(hotspotView)
                    newHotspotModels.append(hotspot)
                }
            }
            hotspotViews = newHotspotViews
            hotspotModels = newHotspotModels
            
            alpha = 0
            UIView.animateWithDuration(0.3) { [weak self] in
                self?.alpha = 1.0
            }
        }
        
        
        
        private func _frameForHotspot(hotspot:PagedPublicationHotspotViewModel) -> CGRect? {
            
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