//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


class VersoPageLayoutAttributes : UICollectionViewLayoutAttributes {
    enum PageContentsAlignment {
        case Center
        case Left
        case Right
    }
    
    var contentsAlignment:PageContentsAlignment = .Center
    
    
    // MARK: NSCopying

    override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! VersoPageLayoutAttributes
        copy.contentsAlignment = self.contentsAlignment
        return copy
    }
    
    override func isEqual(object: AnyObject?) -> Bool {
        
        if let rhs = object as? VersoPageLayoutAttributes {
            if contentsAlignment != rhs.contentsAlignment {
                return false
            }
            return super.isEqual(object)
        } else {
            return false
        }
    }

}



class VersoPagedLayout : UICollectionViewLayout, VersoZoomingReusableViewDelegate {
    
    var spreadSpacing:CGFloat = 10 {
        didSet {
            invalidateLayout()
        }
    }
    var singlePageMode:Bool = false {
        didSet {
            invalidateLayout()
        }
    }
    var firstPageIsSingle:Bool = true {
        didSet {
            invalidateLayout()
        }
    }
    
    private var pageCount:UInt = 0
    private var spreadCount:UInt = 0
    private var spreadSize:CGSize = CGSizeZero

    private var zoomViewAttrs = VersoZoomingReusableViewLayoutAttributes(forDecorationViewOfKind: VersoZoomingReusableView.kind, withIndexPath: NSIndexPath(forItem: 0, inSection: 0))
    
    
    override init() {
        super.init()
        
//        registerClass(VersoZoomingReusableView.self, forDecorationViewOfKind: VersoZoomingReusableView.kind)
//        zoomViewAttrs.zoomDelegate = self;
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    // MARK: Subclassed methods
    
    override func prepareLayout() {
        // TODO: ask delegate
        pageCount = UInt(collectionView?.numberOfItemsInSection(0) ?? 0)
        
        spreadCount = VersoPagedLayout.calculatePageSpreadCount(pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        spreadSize = collectionView?.bounds.size ?? CGSizeZero
        
        _collectionViewContentSize = VersoPagedLayout.calculateContentSize(spreadCount, spreadSize: spreadSize, spreadSpacing:spreadSpacing)
        
        
        collectionView?.pagingEnabled = false
        collectionView?.decelerationRate = UIScrollViewDecelerationRateFast
        
        super.prepareLayout()
    }
    
    
    private var _collectionViewContentSize = CGSizeZero
    override func collectionViewContentSize() -> CGSize {
        return _collectionViewContentSize
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        let oldSize = collectionView?.bounds.size ?? CGSizeZero
        let newSize = newBounds.size
        
        if CGSizeEqualToSize(oldSize, newSize) {
            // TODO: selective invalidation
            return true
        }
        else {
            //[self updateItemSizeForCollectionViewBounds:newBounds];
            return true
        }
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        var allAttrs = [UICollectionViewLayoutAttributes]()
        
        let pageIndexPaths = indexPathsWithinRect(rect)
        for indexPath in pageIndexPaths {
            if let attrs = layoutAttributesForItemAtIndexPath(indexPath) {
                allAttrs.append(attrs)
            }
        }
        
        
        
        // add zoom view to layout attrs
//        let visibleRect = CGRect(origin: collectionView!.contentOffset, size: collectionView!.bounds.size)
//        
//        zoomViewAttrs.frame = visibleRect;
//        zoomViewAttrs.alpha = 0.3;
//        zoomViewAttrs.zIndex = 999;
//        
//        allAttrs.append(zoomViewAttrs)
        
        return allAttrs
    }
    
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        
        let attrs = VersoPageLayoutAttributes(forCellWithIndexPath: indexPath)
        
        let frame = VersoPagedLayout.calculateFrameForPage(UInt(indexPath.item), pageCount: pageCount, spreadSize: spreadSize, spreadSpacing: spreadSpacing, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        attrs.frame = frame
        
        let alignment = VersoPagedLayout.calculateAlignmentForPage(UInt(indexPath.item), pageCount: pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        attrs.contentsAlignment = alignment
        
        
        let visibleRect = CGRect(origin: collectionView!.contentOffset, size: collectionView!.bounds.size)

        
        let isZoomable = CGRectIntersectsRect(attrs.frame, visibleRect);
        
        if isZoomable {
            
            attrs.applyZoomScale(zoomScale, zoomOffset: zoomOffset, zoomViewOrigin: zoomViewAttrs.frame.origin)
            
            attrs.alpha = 1.0;
            attrs.zIndex = 100;
        }
        else
        {
            attrs.alpha = 0.2;
            attrs.zIndex = 1;
        }
        
        return attrs
    }
    
    override func layoutAttributesForDecorationViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
//        if elementKind == VersoZoomingReusableView.kind {
//            return zoomViewAttrs
//        }

        return nil
    }
    
    
    
    override func targetContentOffsetForProposedContentOffset(proposedContentOffset: CGPoint) -> CGPoint {
        return targetContentOffsetForProposedContentOffset(proposedContentOffset, withScrollingVelocity: CGPointZero)
    }

    override func targetContentOffsetForProposedContentOffset(proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        
        guard spreadSize.width > 0 else {
            return proposedContentOffset
        }
        guard collectionView != nil else {
            return proposedContentOffset
        }
        
        var newContentOffset = proposedContentOffset

        let rawSpreadValue = max(collectionView!.contentOffset.x / (spreadSize.width + spreadSpacing), 0)
        let currentSpread = (velocity.x > 0.0) ? floor(rawSpreadValue) : ceil(rawSpreadValue)
        let nextSpread = (velocity.x > 0.0) ? ceil(rawSpreadValue) : floor(rawSpreadValue)

        let flickVelocity = 0.3
        let pannedLessThanAPage = fabs(1 + currentSpread - rawSpreadValue) > 0.5
        let flicked = abs(Double(velocity.x)) > flickVelocity
        
        let targetSpreadIndex = pannedLessThanAPage && flicked ? nextSpread : round(rawSpreadValue)
        
        newContentOffset.x = targetSpreadIndex * (spreadSize.width+spreadSpacing)
        
//        print(rawSpreadValue, currentSpread, nextSpread, targetSpreadIndex, VersoFullScreenLayout.calculateVersoRectoPageIndexes(UInt(rawSpreadValue), pageCount: pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle), VersoFullScreenLayout.calculateVersoRectoPageIndexes(UInt(targetSpreadIndex), pageCount: pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle))
        return newContentOffset
    }
    
    
    
    
    
    
    
    // MARK: Zoom View delegate
    
    private var isZooming = false
    private var zoomScale:CGFloat = 1
    private var zoomOffset:CGPoint = CGPointZero
    
    func updateZoomProperties(scale: CGFloat, offset: CGPoint) {
//        NSLog("zoom: \(scale) \(offset)");
        
        self.zoomScale = scale
        self.zoomOffset = offset
        
        isZooming = zoomScale > 1
        
        // TODO: optimize with specific layout invalidations
        invalidateLayout()
    }
    
    
    
    
    override class func layoutAttributesClass() -> AnyClass {
        return VersoPageLayoutAttributes.self
    }
    
    
    
    
    
    
    // MARK: - Private utility methods
    
    private func indexPathsWithinRect(rect:CGRect) -> [NSIndexPath] {
        
        var indexPaths = [NSIndexPath]()
        
        if let itemCount = collectionView?.numberOfItemsInSection(0) {
            for index in 0..<itemCount {
                indexPaths.append(NSIndexPath(forItem: index, inSection: 0))
            }
        }
        
        return indexPaths;
    }
    
    
    
    private static func calculateContentSize(spreadCount:UInt, spreadSize:CGSize, spreadSpacing:CGFloat) -> CGSize {
        if spreadCount == 0 {
            return CGSizeZero
        }
        return CGSize(width: CGFloat(spreadCount)*spreadSize.width + CGFloat(spreadCount-1)*spreadSpacing, height: spreadSize.height)
        
    }
    private static func calculatePageSpreadCount(pageCount:UInt, singlePageMode:Bool, firstPageIsSingle:Bool) -> UInt {
        guard singlePageMode == false && pageCount > 0 else {
            return max(pageCount, 0)
        }
        
        let spreadCount:UInt
        
        if firstPageIsSingle == true {
            // round the pageCount down if odd, then get half of the _next_ even number
            spreadCount = (pageCount-(pageCount%2) + 2) / 2
        }
        else {
            // round the pageCount up if odd, then get half of the _next_ even number
            spreadCount = ((pageCount+(pageCount%2) + 2) / 2) - 1;
        }
        return spreadCount
    }
    private static func calculateSpreadIndex(pageIndex:UInt, singlePageMode:Bool, firstPageIsSingle:Bool) -> UInt {
        return max(calculatePageSpreadCount(pageIndex+1, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)-1, 0)
    }
    
    private static func calculateVersoRectoPageIndexes(spreadIndex:UInt, pageCount:UInt, singlePageMode:Bool, firstPageIsSingle:Bool) -> (versoIndex:UInt?, rectoIndex:UInt?)? {
        
        guard pageCount > 0 else {
            return nil
        }
        
        var res:(versoIndex:UInt?,rectoIndex:UInt?) = (nil, nil)
        
        
        // is the spread at that index single - first page & single page mode, or all single pages
        if singlePageMode || (spreadIndex == 0 && firstPageIsSingle) {
            /*
             single pageMode
             
             first single:
             0 = [0|-]
             1 = [1|-]
             2 = [-|2]
             3 = [3|-]
             
             !first single:
             0 = [0|-]
             1 = [-|1]
             2 = [2|-]
             2 = [-|3]
             */
            
            let isSpreadOdd = (spreadIndex % 2 == 1)
            
            if firstPageIsSingle {
                if isSpreadOdd || spreadIndex == 0 {
                    res.versoIndex = spreadIndex
                } else {
                    res.rectoIndex = spreadIndex
                }
            }
            else {
                if isSpreadOdd {
                    res.rectoIndex = spreadIndex
                }
                else {
                    res.versoIndex = spreadIndex
                }
            }
        }
        else {
            /*
             first page single
             0 = [0|-] <-- handled in the isSingleSpread case above
             1 = [1|2]
             2 = [3|4]
             3 = [5|-]
             
             !first page single
             0 = [0|1]
             1 = [2|3]
             2 = [4|5]
             3 = [6]
             */
            
            res.versoIndex = spreadIndex * 2
            res.rectoIndex = res.versoIndex! + 1
            
            if firstPageIsSingle {
                res.versoIndex! -= 1
                res.rectoIndex! -= 1
            }
            
            // clamp the recto to the pageCount
            if res.rectoIndex >= pageCount-1 {
                res.rectoIndex = nil
            }
        }
        return res
    }
    
    private static func calculateAlignmentForPage(pageIndex:UInt, pageCount:UInt, singlePageMode:Bool, firstPageIsSingle:Bool) -> VersoPageLayoutAttributes.PageContentsAlignment {
        guard pageIndex < pageCount else {
            return .Center
        }
        
        // single first or last page, or single page mode
        if (singlePageMode ||
            (pageIndex == 0 && firstPageIsSingle) ||
            (pageIndex == pageCount-1 && Bool(pageCount%2) != firstPageIsSingle)) {
            return .Center
        }
        

        let spreadIndex = calculateSpreadIndex(pageIndex, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        if let versoRectoIndexes = calculateVersoRectoPageIndexes(spreadIndex, pageCount: pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle) {
            
            if let versoIndex = versoRectoIndexes.versoIndex where versoIndex == pageIndex {
                return .Right
            }
            else if let rectoIndex = versoRectoIndexes.rectoIndex where rectoIndex == pageIndex {
                return .Left
            }
        }
        return .Center
    }


    private static func calculateFrameForPage(pageIndex:UInt, pageCount:UInt, spreadSize:CGSize, spreadSpacing:CGFloat, singlePageMode:Bool, firstPageIsSingle:Bool) -> CGRect {
        
        let spreadIndex = VersoPagedLayout.calculateSpreadIndex(pageIndex, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        var origin = CGPointZero
        
        // move page by number of preceding spreads
        origin.x += CGFloat(spreadIndex) * (spreadSize.width + spreadSpacing)
        
        
        let isPageSingle = (singlePageMode ||
            (pageIndex == 0 && firstPageIsSingle) ||
            (pageIndex == pageCount-1 && Bool(pageCount%2) != firstPageIsSingle))
        
        var pageSize = spreadSize
        if !isPageSingle {
            
            pageSize.width /= 2
            
            // offset recto pages by 1 page width
            // when first page is single move the even pages,
            // otherwise move the odd pages (but never page 0)
            if  (firstPageIsSingle && pageIndex % 2 == 0) ||
                (!firstPageIsSingle && pageIndex % 2 == 1) {
                origin.x += spreadSize.width/2
            }
        }
        
        return CGRect(origin: origin, size: pageSize)
    }
}


extension UICollectionViewLayoutAttributes {
    
    func applyZoomScale(zoomScale:CGFloat, zoomOffset:CGPoint, zoomViewOrigin:CGPoint) {
        guard zoomScale > 0 else {
            return
        }
        
        frame = CGRect(x: zoomViewOrigin.x*(1-zoomScale) - zoomOffset.x + zoomScale*frame.origin.x,
                       y: zoomViewOrigin.y*(1-zoomScale) - zoomOffset.y + zoomScale*frame.origin.y,
                       width: frame.size.width * zoomScale,
                       height: frame.size.height * zoomScale)
    }
}