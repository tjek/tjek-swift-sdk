//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

protocol HotspotOverlayViewDelegate: class {
    
    func didTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationView.HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint)
    func didLongPressHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationView.HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint)
    func didDoubleTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationView.HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint)
}

// Make the delegate methods optional
extension HotspotOverlayViewDelegate {
    func didTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationView.HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {}
    func didLongPressHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationView.HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {}
    func didDoubleTapHotspot(overlay: PagedPublicationView.HotspotOverlayView, hotspots: [PagedPublicationView.HotspotModel], hotspotRects: [CGRect], locationInOverlay: CGPoint, pageIndex: Int, locationInPage: CGPoint) {}
}

extension PagedPublicationView {
    
    fileprivate class CutoutView: UIView {
        
        var foregroundColor: UIColor = UIColor.black { didSet { setNeedsDisplay() } }
        var maskLayer: CALayer? { didSet { setNeedsDisplay() } }
        
        override func draw(_ rect: CGRect) {
            super.draw(rect)
            
            guard let ctx = UIGraphicsGetCurrentContext() else {
                return
            }
            
            ctx.addRect(rect)
            ctx.setFillColor(foregroundColor.cgColor)
            ctx.fillPath()
            
            if let maskLayer = self.maskLayer {
                ctx.saveGState()
                ctx.setBlendMode(.clear)
                maskLayer.render(in: ctx)
                ctx.restoreGState()
            }
        }
    }
    
    class HotspotOverlayView: UIView, UIGestureRecognizerDelegate {
        
        fileprivate let dimmedOverlay: CutoutView
        fileprivate var hotspotViews: [UIView] = []
        
        public var isZoomedIn: Bool = false
        
        override init(frame: CGRect) {
            
            dimmedOverlay = CutoutView(frame: frame)
            dimmedOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            dimmedOverlay.backgroundColor = UIColor.clear
            dimmedOverlay.foregroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            dimmedOverlay.alpha = 0.0
            dimmedOverlay.isHidden = true
            
            super.init(frame: frame)
            
            _initializeGestureRecognizers()
            
            addSubview(dimmedOverlay)
        }
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        weak var delegate: HotspotOverlayViewDelegate?
        
        fileprivate func _getTargetPage(forGesture gesture: UIGestureRecognizer) -> (index: Int, location: CGPoint)? {
            // find the page that the gesture occurred in
            var possibleTargetPage:(index: Int, location: CGPoint)?
            for (pageIndex, pageView) in pageViews {
                let pageLocation = gesture.location(in: pageView)
                if pageView.bounds.isEmpty == false && pageView.bounds.contains(pageLocation) {
                    possibleTargetPage = (index:pageIndex, location:CGPoint(x: pageLocation.x/pageView.bounds.size.width, y: pageLocation.y/pageView.bounds.size.height))
                    break
                }
            }
            return possibleTargetPage
        }
        
        fileprivate func _getHotspotsAtPoint(_ location: CGPoint) -> [(model: HotspotModel, rect: CGRect)] {
            return hotspotDetails.filter({ $0.rect.contains(location) })
        }
        
        // MARK: - Gestures
        
        var touchGesture: UILongPressGestureRecognizer?
        var tapGesture: UITapGestureRecognizer?
        var longPressGesture: UILongPressGestureRecognizer?
        var doubleTapGesture: UITapGestureRecognizer?
        
        fileprivate func _initializeGestureRecognizers() {
            
            touchGesture = UILongPressGestureRecognizer(target: self, action: #selector(didTouch))
            touchGesture!.minimumPressDuration = 0.01
            touchGesture!.delegate = self
            touchGesture!.cancelsTouchesInView = false
            
            tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tapGesture!.delegate = self
            tapGesture!.cancelsTouchesInView = false
            
            longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
            longPressGesture!.delegate = self
            longPressGesture!.cancelsTouchesInView = false
            
            doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap))
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
                return otherGestureRecognizer == touchGesture
            } else if gestureRecognizer == touchGesture {
                return true
            } else if gestureRecognizer == longPressGesture {
                return otherGestureRecognizer != tapGesture
            } else if gestureRecognizer == doubleTapGesture {
                return true
            } else {
                return false
            }
        }
        
        func updateDimmedOverlayMask(with rects: [CGRect]) {
            
            hotspotViews.forEach({ $0.removeFromSuperview() })
            
            guard rects.count > 0 else {
                dimmedOverlay.isHidden = true
                dimmedOverlay.maskLayer = nil
                return
            }
            
            let rectsMap: (views: [UIView], path: UIBezierPath) = rects.reduce(into: (views: [], path: UIBezierPath())) {
                
                let hotspotView = UIView(frame: $1)
                hotspotView.backgroundColor = UIColor(white: 1, alpha: 0)
                hotspotView.layer.cornerRadius = 4
                hotspotView.layer.borderColor = UIColor.white.cgColor
                hotspotView.layer.borderWidth = 2
                hotspotView.alpha = 0
                
                $0.views.append(hotspotView)
                addSubview(hotspotView)

                $0.path.append(UIBezierPath(roundedRect: $1, cornerRadius: 4))
            }
            
            self.hotspotViews = rectsMap.views
            
            let maskLayer = CAShapeLayer()
            maskLayer.frame = dimmedOverlay.frame
            maskLayer.path = rectsMap.path.cgPath
            maskLayer.fillColor = UIColor.black.cgColor
            
            self.dimmedOverlay.isHidden = false
            self.dimmedOverlay.maskLayer = maskLayer
        }
        
        @objc func fadeOutOverlay() {
            // fade out all hotspot views when touch finishes
            UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.dimmedOverlay.alpha = 0.0
            }, completion: nil)
            
            for hotspotView in hotspotViews {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                    hotspotView.alpha = 0.0
                }, completion: nil)
            }
            
        }
        
        func updateAndFadeInHotspots(at location: CGPoint) {
            
            let hotspots = _getHotspotsAtPoint(location)
            
            updateDimmedOverlayMask(with: hotspots.map({ $0.rect }))
            
            UIView.animate(withDuration: 0.4, delay: 0.1, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.dimmedOverlay.alpha = 0.4
                for hotspotView in self.hotspotViews {
                    hotspotView.alpha = 0.8
                }
            }, completion: nil)
        }
        
        // MARK: Gesture handlers
        
        @objc
        func didTouch(_ touch: UILongPressGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 && !isZoomedIn else {
                return
            }
            
            if touch.state == .began {
                
                let location = touch.location(in: self)
                updateAndFadeInHotspots(at: location)
                
            } else if touch.state == .ended  || touch.state == .cancelled {
                guard tapGesture!.state != .ended else { return }
                
                self.perform(#selector(fadeOutOverlay), with: nil, afterDelay: 0, inModes: [RunLoop.Mode.common])
            }
        }
        @objc
        func didTap(_ tap: UITapGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else {
                return
            }
            
            guard let targetPage = _getTargetPage(forGesture: tap) else {
                return
            }
            
            let overlayLocation = tap.location(in: self)
            let hotspots = _getHotspotsAtPoint(overlayLocation)
            
            UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.dimmedOverlay.alpha = 0.4
                for hotspotView in self.hotspotViews {
                    hotspotView.alpha = 0.8
                }
            }, completion: { [weak self] finished in
                self?.fadeOutOverlay()
            })
            
            delegate?.didTapHotspot(overlay: self, hotspots: hotspots.map({ $0.model }), hotspotRects: hotspots.map({ $0.rect }), locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
        }
        @objc
        func didLongPress(_ press: UILongPressGestureRecognizer) {
            guard bounds.size.width > 0 && bounds.size.height > 0 else { return }
            guard press.state == .began else { return }
            guard let targetPage = _getTargetPage(forGesture: press) else { return }
            
            let overlayLocation = press.location(in: self)
            let hotspots = _getHotspotsAtPoint(overlayLocation)
            
            UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.dimmedOverlay.alpha = 0.4
            })
            
            for hotspotView in hotspotViews {
                UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                    
                    hotspotView.alpha = 0.8
                    hotspotView.backgroundColor = UIColor(white: 1, alpha: 0.8)
                    hotspotView.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.1)
                    
                }, completion: { (finished) in
                    UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.7, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                        hotspotView.layer.transform = CATransform3DIdentity
                    })
                })
            }
            
            delegate?.didLongPressHotspot(overlay: self, hotspots: hotspots.map({ $0.model }), hotspotRects: hotspots.map({ $0.rect }), locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
            
        }
        @objc
        func didDoubleTap(_ doubleTap: UITapGestureRecognizer) {
            
            guard doubleTap.state == .ended else { return }
            guard let targetPage = _getTargetPage(forGesture: doubleTap) else { return }
            
            let overlayLocation = doubleTap.location(in: self)
            let hotspots = _getHotspotsAtPoint(overlayLocation)
            
            delegate?.didDoubleTapHotspot(overlay: self, hotspots: hotspots.map({ $0.model }), hotspotRects: hotspots.map({ $0.rect }), locationInOverlay: overlayLocation, pageIndex: targetPage.index, locationInPage: targetPage.location)
        }
        
        // MARK: Hotspot views
        fileprivate var hotspotDetails: [(model: HotspotModel, rect: CGRect)] = []
        fileprivate var pageViews: [Int: UIView] = [:]
        
        func updateWithHotspots(_ hotspots: [HotspotModel], pageFrames: [Int: CGRect]) {
            
            self.pageViews.forEach({ $0.value.removeFromSuperview() })
            self.pageViews = pageFrames.mapValues {
                let pageView = UIView(frame: $0)
                pageView.isHidden = true
                pageView.isUserInteractionEnabled = false
                pageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(pageView)
                return pageView
            }
            
            let minSize = CGSize(width: min(bounds.size.width * 0.02, 20), height: min(bounds.size.height * 0.02, 20))
            
            self.hotspotDetails = hotspots.compactMap {
                guard let hotspotFrame = _frameForHotspot($0),
                    hotspotFrame.isEmpty == false,
                    hotspotFrame.width > minSize.width,
                    hotspotFrame.height > minSize.height else {
                        return nil
                }
                return ($0, hotspotFrame)
            }
            
            dimmedOverlay.alpha = 0.0
            dimmedOverlay.maskLayer = nil
            
            // hotspot update may come after the touch has started - so show the overlay
            if hotspots.count > 0 && (touchGesture!.state == .began || touchGesture!.state == .changed) {
                let location = touchGesture!.location(in: self)
                updateAndFadeInHotspots(at: location)
            }
        }
        
        fileprivate func _frameForHotspot(_ hotspot: HotspotModel) -> CGRect? {
            return hotspot.pageLocations.reduce(into: nil) {
                guard $1.value.isEmpty == false,
                    let pageFrame = pageViews[$1.key]?.frame else { return }
                
                let hotspotFrame = CGRect(x: pageFrame.origin.x + ($1.value.origin.x * pageFrame.width),
                                          y: pageFrame.origin.y + ($1.value.origin.y * pageFrame.height),
                                          width: $1.value.width * pageFrame.width,
                                          height: $1.value.height * pageFrame.height)
                
                $0 = $0?.union(hotspotFrame) ?? hotspotFrame
            }
        }
        
    }
}
