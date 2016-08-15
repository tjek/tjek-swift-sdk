//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit



public protocol VersoViewDataSource : class {
    associatedtype VersoPageType : UICollectionViewCell
    
    func numberOfPagesInVerso() -> UInt
    
    func configureVersoPage(page:VersoPageType, pageIndex:UInt)
}


public protocol VersoViewDelegate : class {
    
    func versoVisiblePagesDidChange(pageIndexes:NSIndexSet)
    
    func versoPageDidBecomeActive(pageIndex:UInt)
    func versoPageDidBecomeInactive(pageIndex:UInt)
}




public class VersoView<U:VersoViewDataSource> : UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    
    public typealias DataSourceType = U
    typealias PageViewType = U.VersoPageType
    
    
    
    
    override public init(frame: CGRect) {
        super.init(frame:frame)
        
        addSubview(collectionView)
        
    }
    convenience public init() { self.init(frame:CGRectZero) }
    required public init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    deinit {
        dataSource = nil
    }
    
    
    
    
    public weak var dataSource:DataSourceType?
    public weak var delegate:VersoViewDelegate?

    
    
    
    // MARK: Setters
        
    
    // MARK: Getters
    
    /// What page indexes are currently visible. Only changes once page-change animations complete
    // TODO: how does this work with grid layout???
//    public private(set) var currentPageIndexes:(verso:UInt?, recto:UInt?)? = nil {
//        didSet {
//            // TODO: trigger notification/delegate call
//            print("currentPages changed! \(currentPageIndexes)")
//        }
//    }
    
    
    
    /// How many pages did the dataSource provide
    public private(set) var pageCount:UInt = 0
    
    
    
    
    
    /**
     Triggers a re-render of all the pages at the indexes.
     
     Use, for exampple
     
     Will ignore pages that are outside of the pageCount given by the dataSource
     
     If no pageIndexes are provided will re-request data from the dataSource
     
     - Parameter pageIndexes: The indexes of the pages we wish to update. Optional - will update all if omitted
     */
    public func reloadPages(pageIndexes:[UInt]? = nil, animated:Bool) {
        
        // TODO: animations?
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            
            if let idxs = pageIndexes {
                
                var indexPaths = [NSIndexPath]()
                for idx in idxs {
                    indexPaths.append(NSIndexPath(forItem: Int(idx), inSection: 0))
                }
                
                self?.collectionView.reloadItemsAtIndexPaths(indexPaths)
            }
            else {
                // TODO: Try to maintain visible indexes if count changes?
                
                self?.pageCount = self?.dataSource?.numberOfPagesInVerso() ?? 0
                
                self?.collectionView.reloadData()
            }
            
            
            //        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.collectionView.performBatchUpdates({}) { [weak self] finished in
                self?._updateVisiblePageIndexes()
                self?._updateActivePageIndexes()
            }
        }
        
        
    }
    
    
    public func refreshPagesIfVisible(pageIndexes:NSIndexSet) {
        for index in pageIndexes {
            if let cell = collectionView.cellForItemAtIndexPath(NSIndexPath(forItem: index, inSection: 0)) as? PageViewType {
                dataSource?.configureVersoPage(cell, pageIndex: UInt(index))
            }
        }
    }
    
    
    
    /// Move the currently visible page to the specified index
    public func jumpToPage(pageIndex:UInt, animated:Bool) {
        // FIXME: implement jumpToPage
    }
    
    
    
    
    
    
    // MARK: - Private
    
    /// How to layout the pages.
    public var pageLayout:UICollectionViewLayout = VersoPagedLayout() {
        didSet {
            // TODO: add better public updateLayout func
            
            collectionView.setCollectionViewLayout(pageLayout, animated: true)
        }
    }
    
    
    
    
    lazy var collectionView:UICollectionView = {
        let cv = UICollectionView(frame: self.frame, collectionViewLayout: self.pageLayout)
        
        cv.backgroundColor = nil
        cv.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        cv.delegate = self
        cv.dataSource = self
        
        cv.registerClass(PageViewType.self, forCellWithReuseIdentifier: "VersoPage")
        
        return cv
        }()
    
    
    
    
    
    // MARK: - CollectionView DataSource
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(pageCount)
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let pageIndex = UInt(indexPath.item)
        let identifier = "VersoPage"
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(identifier, forIndexPath: indexPath) as! PageViewType        
        
        dataSource?.configureVersoPage(cell, pageIndex: pageIndex)
        
        return cell
    }
    
    
    
    
    
    public func visiblePageView(pageIndex:UInt) -> PageViewType? {
        return collectionView.cellForItemAtIndexPath(NSIndexPath(forItem: Int(pageIndex), inSection: 0)) as? PageViewType
    }
    
    
    public func isPageActive(pageIndex:UInt) -> Bool {
        return _activePageIndexes.containsIndex(Int(pageIndex))
    }
    
    
    // pages that are _fully_ visible. Changes when animations stop.
    private var _activePageIndexes:NSIndexSet = NSIndexSet()
    private func _updateActivePageIndexes() {
        let newActivePageIndexes = _visiblePageIndexes
        
        if newActivePageIndexes.isEqualToIndexSet(_activePageIndexes) == false {
            // calc dif
            let addedIndexes = NSMutableIndexSet(indexSet:newActivePageIndexes)
            addedIndexes.removeIndexes(_activePageIndexes)
            
            let removedIndexes = NSMutableIndexSet(indexSet:_activePageIndexes)
            removedIndexes.removeIndexes(newActivePageIndexes)
            
            _activePageIndexes = newActivePageIndexes
            
            
            // notify delegate of changes
            for added in addedIndexes {
                delegate?.versoPageDidBecomeActive(UInt(added))
            }
            for removed in removedIndexes {
                delegate?.versoPageDidBecomeInactive(UInt(removed))
            }
        }
    }
    
    
    
    
    
    
    
    
    // live-updated list of the visible page indexes
    private var _visiblePageIndexes:NSIndexSet = NSIndexSet()
    private func _updateVisiblePageIndexes() {
    
        let newVisiblePageIndexes = _calculateVisiblePageIndexes()
        
        if newVisiblePageIndexes.isEqualToIndexSet(_visiblePageIndexes) == false {
            _visiblePageIndexes = newVisiblePageIndexes
            _didChangeVisiblePageIndexes()
        }
    }
    private func _calculateVisiblePageIndexes() -> NSIndexSet {
        let indexSet = NSMutableIndexSet()
        
        let indexPaths = collectionView.indexPathsForVisibleItems()
        for indexPath in indexPaths {
            indexSet.addIndex(indexPath.item)
        }
        
        return indexSet
    }
    func _didChangeVisiblePageIndexes() {
        delegate?.versoVisiblePagesDidChange(_visiblePageIndexes)
    }

    
    
    
    
    
    
    
    
    
    
    func didStartScrolling() {
//        print("scrolling started \(_visiblePageIndexes)")

    }
    func didFinishScrolling() {
        
        // maybe update the active pages
        _updateActivePageIndexes()
        
        
        // TODO: scrolling finished notification
//        print("scrolling finished \(_visiblePageIndexes)")
    }
    
    
    
    
    
    
    
    
    // MARK: - CollectionView Delegate
    
    // TODO: update layout with scroll details?
    
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        didStartScrolling()
    }
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        
        _updateVisiblePageIndexes()

//        print("didScroll \(scrollView.contentOffset)")
        
    }
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        didFinishScrolling()
    }
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate && !scrollView.zoomBouncing {
            didFinishScrolling()
        }
    }
    
    
    
    
    
    
    // MARK: - UIView Overrides
    
    override public func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // When Verso is moved to a new superview, reload all the pages.
        // This is basically a 'first-run' event
        if superview != nil {
            reloadPages(animated: false)
        }
    }
    
    
    override public func layoutSubviews() {
        
        // in order to avoid item size warnings, invalidate the layout before the collection view is layed out
        collectionView.collectionViewLayout.invalidateLayout()
        
        super.layoutSubviews()
    }
}









