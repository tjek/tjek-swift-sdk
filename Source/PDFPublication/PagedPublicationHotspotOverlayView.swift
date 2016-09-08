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



extension PagedPublicationView {
    class HotspotOverlayView : UIView {
        
        var pageIndexes:NSIndexSet = NSIndexSet()
        
        private var hotspotsModels:[PagedPublicationHotspotViewModelProtocol] = []
        private var hotspotViews:[UIView] = []
        
        func updateWithHotspots(hotspots:[PagedPublicationHotspotViewModelProtocol]) {
            
            return
            
            
            for hotspotView in hotspotViews {
                hotspotView.removeFromSuperview()
            }
            
            var newHotspotModels:[PagedPublicationHotspotViewModelProtocol] = []
            
            
            for hotspot in hotspots {
                
                var combinedHotspotLocation:CGRect?
                
                let hotspotPageIndexes = hotspot.getPageIndexes()
                for hotspotPageIndex in hotspotPageIndexes {
                    if pageIndexes.containsIndex(hotspotPageIndex) {
                        let hotspotLocation = hotspot.getLocationForPageIndex(hotspotPageIndex)
                        
                        if hotspotLocation.isEmpty == false {
                            combinedHotspotLocation = combinedHotspotLocation?.union(hotspotLocation) ?? hotspotLocation
                        }
                    }
                }
                
                guard combinedHotspotLocation != nil else {
                    continue
                }
//                
//                combinedHotspotLocation!.intersectInPlace(CGRectMake(0,0,1,1))
//                let hotspotFrame = _frameForHotspot(hotspot)
//                
//                newHotspotModels.append(hotspot)
//                
//                let hotspotView = UIView(frame: hotspotFrame)
//                hotspotView.hidden = hotspotFrame.isEmpty
//                hotspotView.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0.8, alpha: 0.5)
//                hotspotView.layer.borderWidth = 1
//                hotspotView.layer.borderColor = UIColor(white: 1, alpha: 0.6).CGColor
//                
//                addSubview(hotspotView)
//                hotspotViews.append(hotspotView)
            }
            
            hotspotsModels = newHotspotModels
        }
        
        
        
//        private func _frameForHotspot(hotspot:PagedPublicationHotspotViewModelProtocol) -> CGRect {
//            
//            let location = hotspot.getLocationForPageIndex(pageIndex).intersect(CGRectMake(0,0,1,1))
//            guard location.isEmpty == false else {
//                return CGRectNull
//            }
//            
//            let maxSize = bounds.size
//            let hotspotFrame = CGRect(x: maxSize.width * location.origin.x,
//                                      y: maxSize.height * location.origin.y,
//                                      width: maxSize.width * location.size.width,
//                                      height: maxSize.height * location.size.height)
//            
//            
//            // we dont want super-thin hotspots
//            guard hotspotFrame.width > 10 && hotspotFrame.height > 10 else {
//                return CGRectNull
//            }
//            
//            return hotspotFrame
//        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
//            for (index, hotspot) in hotspotsModels.enumerate() {
//                if let hotspotView = hotspotViews[safe:index] {
//                    let hotspotFrame = _frameForHotspot(hotspot)
//                    hotspotView.frame = hotspotFrame
//                    hotspotView.hidden = hotspotFrame.isEmpty
//                }
//            }
        }
    }
}