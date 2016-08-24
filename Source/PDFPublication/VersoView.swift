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
public protocol VersoViewDelegate : class {
    optional func activePagesDidChangeForVerso(verso:VersoView, activePageIndexes:NSIndexSet, added:NSIndexSet, removed:NSIndexSet)
    optional func visiblePagesDidChangeForVerso(verso:VersoView, visiblePageIndexes:NSIndexSet, added:NSIndexSet, removed:NSIndexSet)
    
    optional func didStartZoomingPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat)
    optional func didZoomPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat)
    optional func didEndZoomingPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat)
}

@objc
public protocol VersoViewDataSource : class {
    
    /// How many pages does the verso have?
    /// This is called after reloadPages is called on the VersoView
    func pageCountForVerso(verso:VersoView) -> Int
    
    /// Gives the dataSource a chance to configure the pageView
    /// Its `pageIndex` property will have been set, but it's size will not be correct
    func configurePageForVerso(verso:VersoView, pageView:VersoPageView)
    
    /// What subclass of VersoPageView should be used.
    /// This will assert if the result is not a subclass of VersoPageView
    func pageViewClassForVerso(verso:VersoView) -> VersoPageViewClass
    
    
    
    // MARK: Optional
    
    /// Whether the VersoView should show 2 or 1 pages per screen, given the size.
    /// If not implemented Verso will be single-paged if height > width
    optional func isVersoSinglePagedForSize(verso:VersoView, size:CGSize) -> Bool
    
    /// Whether the first page always only shows 1 page, no matter if we show multiple pages the rest of the time
    /// If not implemented the default is true
    optional func isVersoFirstPageAlwaysSingle(verso:VersoView) -> Bool
    
    /// How large the gap is between a screen of pages.
    optional func spreadSpacingForVerso(verso:VersoView) -> CGFloat
    
    /// How zoomed a spread can go
    /// If not implemented will default to 4.0. If <= 1.0 zoom will be disabled.
    optional func maxiumZoomScaleForVerso(verso:VersoView) -> CGFloat
    
    
    //    optional func outroViewForVerso(verso:VersoView) -> UIView?
}



/// The class that should be sub-classed to build your own pages
public class VersoPageView : UIView {
    public private(set) var pageIndex:Int = NSNotFound
    
    /// make init(frame:) required
    required override public init(frame: CGRect) { super.init(frame: frame) }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
}
public typealias VersoPageViewClass = VersoPageView.Type



// MARK: -

public class VersoView : UIView {
    
    // MARK: - Public
    
    public weak var dataSource:VersoViewDataSource? {
        didSet {
            zoomView.maximumZoomScale = dataSource?.maxiumZoomScaleForVerso?(self) ?? 4.0
            firstPageIsSingle = dataSource?.isVersoFirstPageAlwaysSingle?(self) ?? true
            
            //TODO: spacing doesnt work with scrollview paging
            spreadSpacing = 0 //dataSource?.spreadSpacingForVerso?(self) ?? 0
            
            pageCount = 0
            pageViewClass = dataSource?.pageViewClassForVerso(self) ?? VersoPageView.self
            setNeedsLayout()
        }
    }
    
    public weak var delegate:VersoViewDelegate?
    
    
    
    
    public private(set) var pageCount:Int = 0
    
    public func reloadPages() {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard self != nil else { return }
            
            self!.pageCount = self!.dataSource?.pageCountForVerso(self!) ?? 0
            
            self!._updateScrollViewLayout(jumpToPage:0)
        }
    }
    
    public func jumpToPage(pageIndex:Int, animated:Bool) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard self != nil else { return }
            
            let spreadIndex = VersoView.calculateSpreadIndex(pageIndex, singlePageMode: self!.singlePageMode, firstPageIsSingle:self!.firstPageIsSingle)
            
            self!.pageScrollView.setContentOffset(CGPoint(x:self!.spreadSize.width*CGFloat(spreadIndex), y:0), animated: animated)
        }
    }
    
    
    public func reconfigureVisiblePages() {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard self != nil else { return }
            for (_, pageView) in self!.pageViewsByPageIndex {
                self!._configurePageView(pageView)
            }
        }
    }
    
    
    /// Return the VersoPageView for a pageIndex, or nil if the pageView is not in memory
    public func getPageViewIfLoaded(pageIndex:Int) -> VersoPageView? {
        return pageViewsByPageIndex[pageIndex]
    }
    
    
    
    
    
    // MARK: - UIView subclassing
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(pageScrollView)
        
        pageScrollView.addSubview(zoomView)
        
        reloadPages()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        
        let oldBounds = bounds
        
        super.layoutSubviews()

        
        let newSinglePageMode = dataSource?.isVersoSinglePagedForSize?(self, size: bounds.size) ?? (bounds.size.width <= bounds.size.height)
        
        guard oldBounds != bounds || newSinglePageMode != singlePageMode else {
            return
        }
        
        singlePageMode = newSinglePageMode
        
        // recalc all layout states, and update spreads (targetr active page)
        let firstActivePageIndex = activePageIndexes.firstIndex == NSNotFound ? 0 : activePageIndexes.firstIndex
        _updateScrollViewLayout(jumpToPage:firstActivePageIndex)
        
        _updateActivePageIndexes()
        _updateVisiblePageIndexes()
        
        _enableZoomingForActivePageViews(force:true)
    }
    
    override public func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // When Verso is moved to a new superview, reload all the pages.
        // This is basically a 'first-run' event
        if superview != nil {
            reloadPages()
        }
    }
    
    
    
    
    
    
    
    
    // MARK: - Private Proprties
    
    // layout properties
    private var singlePageMode:Bool = false
    private var firstPageIsSingle:Bool = true
    private var spreadSpacing:CGFloat = 0
    
    
    // layout state
    private var spreadCount:Int = 0
    private var spreadSize:CGSize = CGSizeZero
    
    
    // pages that are _fully_ visible. Changes when animations stop.
    public private(set) var activePageIndexes:NSIndexSet = NSIndexSet()
    
    // live-updated list of the visible page indexes
    public private(set) var visiblePageIndexes:NSIndexSet = NSIndexSet()
    
    // the pageViews that are currently being used
    private var pageViewsByPageIndex = [Int:VersoPageView]()
    
    // the pageIndexes that are embedded in the zoomView
    private var zoomingPageIndexes:NSIndexSet = NSIndexSet()
    
    // The class to instantiate when creating a new pageView
    private var pageViewClass:VersoPageViewClass = VersoPageView.self
    
    
    
    
    
    
    
    // MARK: - Spread Layout
    
    
    // recalculate the contentSize & offset of the pageScrollView.
    // Uses the first activePageIndex as a target for where to position the
    private func _updateScrollViewLayout(jumpToPage targetPageIndex:Int) {
        
        // update layout properties
        spreadSize = bounds.size
        spreadCount = VersoView.calculatePageSpreadCount(pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        var pageToJumpTo = targetPageIndex
        if pageToJumpTo >= pageCount {
            pageToJumpTo = 0
        }
        
        let activeSpreadIndex = VersoView.calculateSpreadIndex(pageToJumpTo, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        
        // adjust the contentSize based on spread count
        pageScrollView.contentSize = CGSize(width: (spreadSize.width+spreadSpacing)*CGFloat(spreadCount),
                                            height: spreadSize.height)
        
        pageScrollView.contentOffset = CGPoint(x:(spreadSize.width+spreadSpacing)*CGFloat(activeSpreadIndex), y:0)
        
        _updatePageLayouts()
        
        _updateActivePageIndexes()
        _updateVisiblePageIndexes()
        
        _enableZoomingForActivePageViews(force:true)
    }
    
    
    /// Create, rearrange, reposition, and configure all PageViews necessary to fill a buffer frame around the visible area
    private func _updatePageLayouts() {
        let visibleFrame = pageScrollView.bounds
        
        
        let spreadWidth = visibleFrame.size.width
        // generate frame that we will pre-config the pages for
        let pagePreloadFrame = UIEdgeInsetsInsetRect(visibleFrame, UIEdgeInsetsMake(0, -spreadWidth, 0, -(spreadWidth*6)))
        
        
        let requiredPageIndexes = VersoView.calculateVisiblePageIndexesInRect(pagePreloadFrame, pageCount: pageCount, spreadSize: spreadSize, spreadSpacing: spreadSpacing, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        
        var newPageViewsByPageIndex = [Int:VersoPageView]()
        
        
        // page indexes that dont have a view
        let missingPageViewIndexes = NSMutableIndexSet(indexSet: requiredPageIndexes)
        // page views that aren't needed anymore
        var recyclablePageViews = [VersoPageView]()
        
        
        // go through all the page views we have, and find out what we need
        for (pageIndex, pageView) in pageViewsByPageIndex {
            
            if requiredPageIndexes.containsIndex(pageIndex) == false && zoomingPageIndexes.containsIndex(pageIndex) == false {
                // we have a page view that can be recycled
                recyclablePageViews.append(pageView)
            } else {
                missingPageViewIndexes.removeIndex(pageIndex)
                newPageViewsByPageIndex[pageIndex] = pageView
                
                // reposition the pageview (if not being zoomed)
                if zoomingPageIndexes.containsIndex(pageIndex) == false {
                    _positionPageView(pageView, pageIndex: pageIndex)
                }
                
                //                pageView.layer.zPosition = pageScrollView.contentSize.width - fabs(CGRectGetMidX(visibleFrame) - CGRectGetMidX(pageView.frame))
            }
        }
        
        
        // get spreadviews for all the missing indexes
        for pageIndex in missingPageViewIndexes {
            
            let pageView:VersoPageView
            
            
            if recyclablePageViews.isEmpty == false {
                pageView = recyclablePageViews.removeLast()
            }
            else {
                // need to give new PageViews an initial frame otherwise they fly in from 0,0
                let initialFrame = VersoView.calculateFrameForPage(pageIndex, pageCount: pageCount, spreadSize: spreadSize, spreadSpacing: spreadSpacing, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
                
                pageView = pageViewClass.init(frame:initialFrame)
                pageScrollView.insertSubview(pageView, aboveSubview: zoomView)
            }
            
            pageView.pageIndex = pageIndex
            
            _configurePageView(pageView)
            
            _positionPageView(pageView, pageIndex: pageIndex)
            
            newPageViewsByPageIndex[pageIndex] = pageView
        }
        
        // clean up any unused recyclables
        for pageView in recyclablePageViews {
            pageView.removeFromSuperview()
        }
        
        pageViewsByPageIndex = newPageViewsByPageIndex
    }
    
    
    private func _positionPageView(pageView:VersoPageView, pageIndex:Int) {
        
        let maxFrame = VersoView.calculateFrameForPage(pageIndex, pageCount: pageCount, spreadSize: spreadSize, spreadSpacing: spreadSpacing, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        let pageSize = pageView.sizeThatFits(maxFrame.size)
        
        
        var pageFrame = maxFrame
        pageFrame.size = pageSize
        pageFrame.origin.y = round(CGRectGetMidY(maxFrame) - pageSize.height/2)
        
        
        let alignment = VersoView.calculateAlignmentForPage(pageIndex, pageCount: pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        switch alignment {
        case .Left:
            pageFrame.origin.x = CGRectGetMinX(maxFrame)
        case .Right:
            pageFrame.origin.x = CGRectGetMaxX(maxFrame) - pageSize.width
        case .Center:
            pageFrame.origin.x = round(CGRectGetMidX(maxFrame) - pageSize.width/2)
        }
        
        pageView.frame = pageFrame
    }
    
    
    
    private func _configurePageView(pageView:VersoPageView) {
        if pageView.pageIndex != NSNotFound {
            dataSource?.configurePageForVerso(self, pageView: pageView)
        }
    }
    
    
    
    
    // MARK: - Scrolling Pages
    
    private func _didStartScrolling() {
        
    }
    @objc private func _didFinishScrolling() {
        // maybe update the active pages
        _updateActivePageIndexes()
        
        _enableZoomingForActivePageViews(force: false)
    }
    
    
    
    
    
    
    // MARK: - Zooming
    
    /*
     Resets the zoomView to correct location and adds pageviews that will be zoomed
     Must be called after updateActivePages
     */
    private func _enableZoomingForActivePageViews(force force:Bool) {
        
        guard zoomingPageIndexes != activePageIndexes || force else {
            return
        }
        
        // reset previous zooming pageViews
        for pageIndex in zoomingPageIndexes {
            if let pageView = pageViewsByPageIndex[pageIndex] {
                pageScrollView.insertSubview(pageView, aboveSubview: zoomView)
                _positionPageView(pageView, pageIndex: pageIndex)
            }
        }
        
        
        
        // update which pages are zooming
        zoomingPageIndexes = activePageIndexes
        
        
        
        // TODO: remember the zoomscale / content offset & reapply after frame adjustment
        
        // reset the zoomview
        zoomView.zoomScale = 1.0
        zoomView.contentInset = UIEdgeInsetsZero
        zoomView.contentOffset = CGPointZero
        
        // move zoomview visible frame
        zoomView.frame = pageScrollView.bounds
        
        
        // reset the zoomContents to fill the zoomView
        zoomViewContents.frame = zoomView.bounds
        
        
        // get the PageViews that will be in zoomview, and the combined frame for all those views
        var combinedPageFrame = CGRectZero
        
        var activePageViews = [VersoPageView]()
        for pageIndex in zoomingPageIndexes {
            if let pageView = pageViewsByPageIndex[pageIndex] {
                activePageViews.append(pageView)
                
                let pageViewFrame = pageView.convertRect(pageView.bounds, toView: zoomView)
                combinedPageFrame = combinedPageFrame==CGRectZero ? pageViewFrame : combinedPageFrame.union(pageViewFrame)
            }
        }
        
        
        zoomView.contentSize = combinedPageFrame.size
        zoomViewContents.frame = combinedPageFrame
        
        for pageView in activePageViews {
            
            let newPageFrame = zoomViewContents.convertRect(pageView.bounds, fromView: pageView)
            pageView.frame = newPageFrame
            zoomViewContents.addSubview(pageView)
        }
        
        zoomViewContents.frame = CGRect(origin: CGPointZero, size: combinedPageFrame.size)
        
        zoomView.targetContentFrame = combinedPageFrame
    }
    
    private func _didStartZooming() {
        if zoomingPageIndexes.count > 0 {
            delegate?.didStartZoomingPagesForVerso?(self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
        }
    }
    
    private func _didZoom() {
        if zoomingPageIndexes.count > 0 {
            delegate?.didZoomPagesForVerso?(self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
        }
    }
    
    private func _didEndZooming() {
        if zoomView.zoomScale <= zoomView.minimumZoomScale {
            
            // TODO: when zoomed in/out we should enable/disable page scrolling
            //            pageScrollView.scrollEnabled = true
        }
        
        
        if zoomingPageIndexes.count > 0 {
            delegate?.didEndZoomingPagesForVerso?(self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
        }
    }
    
    
    
    
    
    // MARK: - Visible & Active pages
    private func _updateVisiblePageIndexes() {
        
        let visibleFrame = pageScrollView.bounds
        
        let newVisiblePageIndexes = VersoView.calculateVisiblePageIndexesInRect(visibleFrame, pageCount: pageCount, spreadSize: spreadSize, spreadSpacing: spreadSpacing, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        if newVisiblePageIndexes.isEqualToIndexSet(visiblePageIndexes) == false {
            // calc diff
            let addedIndexes = NSMutableIndexSet(indexSet:newVisiblePageIndexes)
            addedIndexes.removeIndexes(visiblePageIndexes)
            
            let removedIndexes = NSMutableIndexSet(indexSet:visiblePageIndexes)
            removedIndexes.removeIndexes(newVisiblePageIndexes)
            
            visiblePageIndexes = newVisiblePageIndexes
            
            delegate?.visiblePagesDidChangeForVerso?(self, visiblePageIndexes: visiblePageIndexes, added: addedIndexes, removed: removedIndexes)
        }
    }
    
    private func _updateActivePageIndexes() {
        
        let visibleFrame = pageScrollView.bounds
        
        let newActivePageIndexes = VersoView.calculateVisiblePageIndexesInRect(visibleFrame, pageCount: pageCount, spreadSize: spreadSize, spreadSpacing: spreadSpacing, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        if newActivePageIndexes.isEqualToIndexSet(activePageIndexes) == false {
            // calc diff
            let addedIndexes = NSMutableIndexSet(indexSet:newActivePageIndexes)
            addedIndexes.removeIndexes(activePageIndexes)
            
            let removedIndexes = NSMutableIndexSet(indexSet:activePageIndexes)
            removedIndexes.removeIndexes(newActivePageIndexes)
            
            activePageIndexes = newActivePageIndexes
            
            delegate?.activePagesDidChangeForVerso?(self, activePageIndexes: activePageIndexes, added: addedIndexes, removed: removedIndexes)
        }
    }
    
    
    
    
    
    // MARK: - Subviews
    
    lazy var pageScrollView:UIScrollView = {
        let view = UIScrollView(frame:self.frame)
        view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        view.delegate = self
        view.pagingEnabled = true
        
        view.decelerationRate = UIScrollViewDecelerationRateFast
        return view
    }()
    
    
    private lazy var zoomView:InsetZoomView = {
        let view = InsetZoomView(frame:self.frame)
        view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        view.addSubview(self.zoomViewContents)

        
        view.delegate = self
        view.maximumZoomScale = 4.0
        
        view.sgn_enableDoubleTapGestures()

        //        view.backgroundColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.3)
        return view
    }()
    
    private lazy var zoomViewContents:UIView = {
        let view = UIView()
        //        view.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.3)
        return view
    }()
    
}




// MARK: - UIScrollViewDelegate

extension VersoView : UIScrollViewDelegate {
    
    // MARK: Paging
    
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            _didStartScrolling()
        }
    }
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            _updatePageLayouts()
            _updateVisiblePageIndexes()
        }
        
    }
    public func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            // cancel any delayed didFinishScrolling requests - see `scrollViewDidEndDecelerating`
            NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(VersoView._didFinishScrolling), object: nil)
        }
    }
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            
            var delay:NSTimeInterval = 0
            // There are some edge cases where, when dragging rapidly, we get a decel finished event, and then a bounce-back decel again
            // In that case (where scrolled out of bounds and decel finished) wait before triggering didEndScrolling
            // We delay rather than just not calling to make sure we dont end up in the situation where didEndScrolling is never called
            if scrollView.bounces && (CGRectGetMaxX(scrollView.bounds) > scrollView.contentSize.width || CGRectGetMinX(scrollView.bounds) < 0 || CGRectGetMaxY(scrollView.bounds) > scrollView.contentSize.height || CGRectGetMinY(scrollView.bounds) < 0) {
                delay = 0.2
            }
            NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(VersoView._didFinishScrolling), object: nil)
            self.performSelector(#selector(VersoView._didFinishScrolling), withObject: nil, afterDelay: delay)
        }
    }
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == pageScrollView {
            if !decelerate && !scrollView.zoomBouncing {
                _didFinishScrolling()
            }
        }
    }
    public func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            _didFinishScrolling()
        }
    }
    
    
    // MARK: Zooming
    public func scrollViewWillBeginZooming(scrollView: UIScrollView, withView view: UIView?) {
        if scrollView == zoomView {
            _didStartZooming()
        }
    }
    public func scrollViewDidZoom(scrollView: UIScrollView) {
        if scrollView == zoomView {
            _didZoom()
        }
    }
    public func scrollViewDidEndZooming(scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        if scrollView == zoomView {
            _didEndZooming()
        }
    }
    public func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        if scrollView == zoomView {
            return zoomViewContents
        }
        return nil
    }
    
}





// MARK: - Layout Utilities

extension VersoView {
    
    private static func calculateSpreadIndex(pageIndex:Int, singlePageMode:Bool, firstPageIsSingle:Bool) -> Int {
        return max(calculatePageSpreadCount(pageIndex+1, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)-1, 0)
    }
    
    private static func calculatePageSpreadCount(pageCount:Int, singlePageMode:Bool, firstPageIsSingle:Bool) -> Int {
        guard singlePageMode == false && pageCount > 0 else {
            return max(pageCount, 0)
        }
        
        let spreadCount:Int
        
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
    
    
    private static func calculateVisibleSpreadIndexesInRect(rect:CGRect, spreadCount:Int, spreadSize:CGSize, spreadSpacing:CGFloat) -> NSIndexSet {
        let indexes = NSMutableIndexSet()
        
        guard spreadSize.width > 0 else {
            return indexes
        }
        
        guard spreadCount > 0 else {
            return indexes
        }
        
        let firstSpreadIndex = max(min(Int(floor((CGRectGetMinX(rect)+1) / (spreadSize.width + spreadSpacing))), spreadCount-1), 0)
        let lastSpreadIndex = max(min(Int(floor((CGRectGetMaxX(rect)-1) / (spreadSize.width + spreadSpacing))), spreadCount-1), firstSpreadIndex)
        
        indexes.addIndexesInRange(NSMakeRange(firstSpreadIndex, lastSpreadIndex - firstSpreadIndex + 1))
        
        return indexes
    }
    
    private static func calculateFrameForSpread(spreadIndex:Int, spreadSize:CGSize, spreadSpacing:CGFloat) -> CGRect {
        
        return CGRect(origin: CGPoint(x:CGFloat(spreadIndex) * (spreadSize.width + spreadSpacing),y:0),
                      size: spreadSize)
    }
    
    
    
    private static func calculateFrameForPage(pageIndex:Int, pageCount:Int, spreadSize:CGSize, spreadSpacing:CGFloat, singlePageMode:Bool, firstPageIsSingle:Bool) -> CGRect {
        
        let spreadIndex = calculateSpreadIndex(pageIndex, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        let pageIndexLayout = calculateSpreadPageIndexLayout(spreadIndex, pageCount: pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        let spreadFrame = calculateFrameForSpread(spreadIndex, spreadSize: spreadSize, spreadSpacing: spreadSpacing)
        
        var frame = spreadFrame
        
        switch pageIndexLayout {
        case .TwoUp(let verso, _) where verso == pageIndex:
            frame.size.width /= 2
        case .TwoUp(_, let recto) where recto == pageIndex:
            frame.size.width /= 2
            frame.origin.x += frame.size.width
        default:break
        }
        
        return frame
    }
    
    private static func calculateAlignmentForPage(pageIndex:Int, pageCount:Int, singlePageMode:Bool, firstPageIsSingle:Bool) -> SpreadPageAlignemnt {
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
        
        let pageIndexLayout = calculateSpreadPageIndexLayout(spreadIndex, pageCount: pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        switch pageIndexLayout {
        case let .TwoUp(versoIndex, _) where versoIndex == pageIndex:
            return .Right
        case let .TwoUp(_, rectoIndex) where rectoIndex == pageIndex:
            return .Left
        default:
            return .Center
        }
    }
    
    
    
    private static func calculateVisiblePageIndexesInRect(rect:CGRect, pageCount:Int, spreadSize:CGSize, spreadSpacing:CGFloat, singlePageMode:Bool, firstPageIsSingle:Bool) -> NSIndexSet {
        
        let indexes = NSMutableIndexSet()
        
        let spreadCount = calculatePageSpreadCount(pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle)
        
        let spreadIndexes = calculateVisibleSpreadIndexesInRect(rect, spreadCount:spreadCount, spreadSize:spreadSize, spreadSpacing:spreadSpacing)
        for spreadIndex in spreadIndexes {
            let pageIndexes = calculateSpreadPageIndexLayout(spreadIndex, pageCount:pageCount, singlePageMode: singlePageMode, firstPageIsSingle: firstPageIsSingle).allPageIndexes()
            
            indexes.addIndexes(pageIndexes)
        }
        return indexes
    }
    
    private static func calculateSpreadPageIndexLayout(spreadIndex:Int, pageCount:Int, singlePageMode:Bool, firstPageIsSingle:Bool) -> SpreadPageIndexLayout {
        
        guard pageCount > 0 else {
            return .None
        }
        
        // is the spread at that index single - first page & single page mode, or all single pages
        if singlePageMode || (spreadIndex == 0 && firstPageIsSingle) {
            
            return .Single(pageIndex: spreadIndex)
        }
        else {
            /*
             first page single
             0 = [-0-] <-- handled in the isSingleSpread case above
             1 = [1|2]
             2 = [3|4]
             3 = [-5-]
             
             !first page single
             0 = [0|1]
             1 = [2|3]
             2 = [4|5]
             3 = [-6-]
             */
            
            var versoIndex = spreadIndex * 2
            var rectoIndex = versoIndex + 1
            
            if firstPageIsSingle {
                versoIndex -= 1
                rectoIndex -= 1
            }
            
            // recto is outside pageCount so it's a verso-only single page
            if rectoIndex >= pageCount-1 {
                return .Single(pageIndex: versoIndex)
            }
            else {
                return .TwoUp(versoIndex: versoIndex, rectoIndex: rectoIndex)
            }
        }
    }
}



// MARK: - Utility Zooming View subclass
extension VersoView {
    
    // A Utility zooming view that will modify the contentInsets to keep the content matching a target frame
    class InsetZoomView : UIScrollView {
        
        /// This is the frame we wish the contentsView to occupy. contentInset is adjusted to maintain that frame.
        /// If this is nil the contents will be centered
        var targetContentFrame:CGRect? { didSet {
            _updateZoomContentInsets()
            }
        }
        
        override func layoutSublayersOfLayer(layer: CALayer) {
            super.layoutSublayersOfLayer(layer)
            
            _updateZoomContentInsets()
        }
        
        private func _updateZoomContentInsets() {
            
            if let contentView = delegate?.viewForZoomingInScrollView?(self) {
                self.contentInset = _targetedInsets(contentView)
            }
        }
        
        private func _targetedInsets(contentView:UIView) -> UIEdgeInsets {
            
            var edgeInset = UIEdgeInsetsZero
            
            // the goal frame of the contentsView when not zoomed in
            let unscaledTargetFrame = self.targetContentFrame ?? CGRect(origin:CGPointMake(CGRectGetMidX(bounds)-(contentView.bounds.size.width/2), CGRectGetMidY(bounds)-(contentView.bounds.size.height/2)), size:contentView.bounds.size)
            
            // calc what percentage of non-contents space the origin distance is
            var percentageOfRemainingSpace = CGPointZero
            percentageOfRemainingSpace.x = bounds.size.width != unscaledTargetFrame.size.width ? unscaledTargetFrame.origin.x/(bounds.size.width-unscaledTargetFrame.size.width) : 1
            percentageOfRemainingSpace.y = bounds.size.height != unscaledTargetFrame.size.height ? unscaledTargetFrame.origin.y/(bounds.size.height-unscaledTargetFrame.size.height) : 1
            
            
            // scale the contentFrame's origin based on desired percentage of remaining space
            var scaledTargetFrame = contentView.frame
            scaledTargetFrame.origin.x = (bounds.size.width - scaledTargetFrame.size.width) * percentageOfRemainingSpace.x
            scaledTargetFrame.origin.y = (bounds.size.height - scaledTargetFrame.size.height) * percentageOfRemainingSpace.y
            
            
            if bounds.size.height > scaledTargetFrame.size.height {
                edgeInset.top = scaledTargetFrame.origin.y + (bounds.origin.y - contentOffset.y)
            }
            if bounds.size.width > scaledTargetFrame.size.width {
                edgeInset.left = scaledTargetFrame.origin.x + (bounds.origin.x - contentOffset.x)
            }
            
            return edgeInset
        }
    }
}



// MARK: - Spread layout properties
extension VersoView {
    
    enum SpreadPageIndexLayout {
        case None
        case Single(pageIndex:Int)
        case TwoUp(versoIndex:Int, rectoIndex:Int)
        
        
        // get a set of all the page indexes
        func allPageIndexes() -> NSIndexSet {
            
            let pageIndexes = NSMutableIndexSet()
            switch self {
            case let .Single(pageIndex):
                pageIndexes.addIndex(pageIndex)
            case let .TwoUp(verso, recto):
                pageIndexes.addIndex(verso)
                pageIndexes.addIndex(recto)
            default:break
            }
            return pageIndexes
        }
    }
    
    
    enum SpreadPageAlignemnt {
        case Center
        case Left
        case Right
    }
}

extension VersoView.SpreadPageIndexLayout: Equatable { }
func ==(lhs: VersoView.SpreadPageIndexLayout, rhs: VersoView.SpreadPageIndexLayout) -> Bool {
    switch (lhs, rhs) {
    case (let .Single(pageIndex1), let .Single(pageIndex2)):
        return pageIndex1 == pageIndex2
        
    case (let .TwoUp(verso1, recto1), let .TwoUp(verso2, recto2)):
        return verso1 == verso2 && recto1 == recto2
        
    case (.None, .None):
        return true
        
    default:
        return false
    }
}




extension UIScrollView {

    public func sgn_enableDoubleTapGestures() {
        // create and add the gesture recognizer
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(UIScrollView._sgn_didDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        
        addGestureRecognizer(doubleTap)

    }

    // TODO: add disable func
    // TODO: add doubleTap gesture accessor
    // TODO: allow to disable double-tap animations
    
    @objc
    private func _sgn_didDoubleTap(tap:UITapGestureRecognizer) {
        guard tap.state == .Ended else {
            return
        }
        
        // no-op if zoom is disabled
        guard pinchGestureRecognizer != nil && pinchGestureRecognizer!.enabled == true else {
            return
        }
        
        // no zoom, so eject
        guard minimumZoomScale < maximumZoomScale else {
            return
        }
        
        guard let zoomedView = delegate?.viewForZoomingInScrollView?(self) else {
            return
        }
        
        // fake 'willBegin'
        delegate?.scrollViewWillBeginZooming?(self, withView:zoomedView)

        let zoomedIn = zoomScale > minimumZoomScale
        
        
        let zoomAnimations = {
            if zoomedIn {
                // zoomed in - so zoom out again
                self.setZoomScale(self.minimumZoomScale, animated: false)
            }
            else {
                // zoomed out - find the rect we want to zoom to
                let targetScale = self.maximumZoomScale
                let targetCenter = tap.locationInView(zoomedView)
                    //zoomedView.convertPoint(tap.locationInView(self), fromView: self)
                
                var targetZoomRect = CGRectZero
                targetZoomRect.size = CGSize(width: zoomedView.frame.size.width / targetScale,
                                             height: zoomedView.frame.size.height / targetScale)
                
                targetZoomRect.origin = CGPoint(x: targetCenter.x - ((targetZoomRect.size.width / 2.0)),
                                                y: targetCenter.y - ((targetZoomRect.size.height / 2.0)))
                
                self.zoomToRect(targetZoomRect, animated: false)
            }

        }
    
        let animated = true
        
        
        // here we use a custom animation to make zooming faster/nicer
        let duration:NSTimeInterval = zoomedIn ? 0.30 : 0.40;
        let damping:CGFloat = zoomedIn ? 0.9 : 0.8;
        let initialVelocity:CGFloat = zoomedIn ? 0.9 : 0.75;

    
        UIView.animateWithDuration(animated ? duration : 0, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: initialVelocity, options: [.BeginFromCurrentState], animations: zoomAnimations) { [weak self] finished in
            
            if self != nil && finished {
                // fake 'didZoom'
                self!.delegate?.scrollViewDidEndZooming?(self!, withView:zoomedView, atScale:self!.zoomScale)
            }
        }
    }
}

