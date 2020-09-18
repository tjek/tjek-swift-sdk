//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import Verso

// MARK: - Verso DataSource

extension PagedPublicationView: VersoViewDataSource {
    
    // Return how many pages are on each spread
    public func spreadConfiguration(with size: CGSize, for verso: VersoView) -> VersoSpreadConfiguration {
        let pageCount = self.pageCount
        let lastPageIndex = max(0, pageCount - 1)
        var totalPageCount = pageCount
        
        // there is an outro, and we have some pages, so add outro to the pages list
        if self.outroPageIndex != nil {
            totalPageCount += 1
        }
        
        // how far between the page spreads
        let spreadSpacing: CGFloat = 20
        
        // TODO: compare verso aspect ratio to publication aspect ratio
        let isLandscape: Bool = size.width > size.height
        
        return VersoSpreadConfiguration.buildPageSpreadConfiguration(pageCount: totalPageCount, spreadSpacing: spreadSpacing, spreadPropertyConstructor: { (_, nextPageIndex) in
            
            // it's the outro (has an outro, we have some real pages, and next page is after the last pageIndex
            if let outroProperties = self.outroViewProperties, nextPageIndex == self.outroPageIndex {
                return (1, outroProperties.maxZoom, outroProperties.width)
            }
            
            let spreadPageCount: Int
            if nextPageIndex == 0
                || nextPageIndex == lastPageIndex
                || isLandscape == false {
                spreadPageCount = 1
            } else {
                spreadPageCount = 2
            }
            return (spreadPageCount, 4.0, 1.0)
        })
    }
    
    public func pageViewClass(on pageIndex: Int, for verso: VersoView) -> VersoPageViewClass {
        if let outroProperties = self.outroViewProperties, pageIndex == self.outroPageIndex {
            return outroProperties.viewClass
        } else {
            return PagedPublicationView.PageView.self
        }
    }
    
    public func configure(pageView: VersoPageView, for verso: VersoView) {
        if let pubPageView = pageView as? PagedPublicationView.PageView {
            pubPageView.imageLoader = self.imageLoader
            pubPageView.delegate = self
            let pageProperties = self.pageViewProperties(forPageIndex: pubPageView.pageIndex)
            pubPageView.configure(with: pageProperties)
        } else if type(of: pageView) === self.outroViewProperties?.viewClass {
            dataSourceWithDefaults.configure(outroView: pageView, for: self)
        }
    }
    
    public func spreadOverlayView(overlaySize: CGSize, pageFrames: [Int: CGRect], for verso: VersoView) -> UIView? {
        // we have an outro and it is one of the pages we are being asked to add an overlay for
        if let outroPageIndex = self.outroPageIndex, pageFrames[outroPageIndex] != nil {
            return nil
        }
        
        let spreadHotspots = self.hotspotModels(onPageIndexes: IndexSet(pageFrames.keys))
            
        // configure the overlay
        self.hotspotOverlayView.isHidden = self.pageCount == 0
        self.hotspotOverlayView.delegate = self
        self.hotspotOverlayView.frame.size = overlaySize
        self.hotspotOverlayView.updateWithHotspots(spreadHotspots, pageFrames: pageFrames)
        
        // disable tap when double-tapping
        if let doubleTap = contentsView.versoView.zoomDoubleTapGestureRecognizer {
            self.hotspotOverlayView.tapGesture?.require(toFail: doubleTap)
        }
        
        return self.hotspotOverlayView
    }
    
    public func adjustPreloadPageIndexes(_ preloadPageIndexes: IndexSet, visiblePageIndexes: IndexSet, for verso: VersoView) -> IndexSet? {
        guard let outroPageIndex = self.outroPageIndex, let lastIndex = visiblePageIndexes.last, outroPageIndex - lastIndex < 10 else {
            return nil
        }
        // add outro to preload page indexes if we have scrolled close to it
        var adjustedPreloadPages = preloadPageIndexes
        adjustedPreloadPages.insert(outroPageIndex)
        return adjustedPreloadPages
    }
}

// MARK: - Verso Delegate

extension PagedPublicationView: VersoViewDelegate {
    
    public func currentPageIndexesChanged(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in verso: VersoView) {
        // this is a bit of a hack to cancel the touch-gesture when we start scrolling
        self.hotspotOverlayView.touchGesture?.isEnabled = false
        self.hotspotOverlayView.touchGesture?.isEnabled = true
        
        if currentPageIndexes != oldPageIndexes {
            lifecycleEventTracker?.spreadDidDisappear()
        }
        
        // remove the outro index when refering to page indexes outside of PagedPub
        var currentExOutro = currentPageIndexes
        var oldExOutro = oldPageIndexes
        if let outroIndex = self.outroPageIndex {
            currentExOutro.remove(outroIndex)
            oldExOutro.remove(outroIndex)
        }
        delegate?.pageIndexesChanged(current: currentExOutro, previous: oldExOutro, in: self)
        
        // check if the outro has newly appeared or disappeared (not if it's in both old & current)
        if let outroIndex = outroPageIndex, let outroView = verso.getPageViewIfLoaded(outroIndex) {
            
            let addedIndexes = currentPageIndexes.subtracting(oldPageIndexes)
            let removedIndexes = oldPageIndexes.subtracting(currentPageIndexes)
            
            if addedIndexes.contains(outroIndex) {
                delegate?.outroDidAppear(outroView, in: self)
                outroOutsideTapGesture.isEnabled = true
            } else if removedIndexes.contains(outroIndex) {
                delegate?.outroDidDisappear(outroView, in: self)
                outroOutsideTapGesture.isEnabled = false
            }
        }
        updateContentsViewLabels(pageIndexes: currentPageIndexes, additionalLoading: contentsView.properties.showAdditionalLoading)
    }
    
    public func currentPageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in verso: VersoView) {
        // make a new spreadEventHandler (unless it's the outro)
        if self.isOutroPage(inPageIndexes: currentPageIndexes) == false {
           
            let loadedIndexes = currentPageIndexes.filter { (verso.getPageViewIfLoaded($0) as? PagedPublicationView.PageView)?.isViewImageLoaded ?? false }
            lifecycleEventTracker?.spreadDidAppear(
                pageIndexes: currentPageIndexes,
                loadedIndexes: IndexSet(loadedIndexes))
        }
        
        // remove the outro index when refering to page indexes outside of PagedPub
        var currentExOutro = currentPageIndexes
        var oldExOutro = oldPageIndexes
        if let outroIndex = self.outroPageIndex {
            currentExOutro.remove(outroIndex)
            oldExOutro.remove(outroIndex)
        }
        delegate?.pageIndexesFinishedChanging(current: currentExOutro, previous: oldExOutro, in: self)
        
        // cancel the loading of the zoomimage after a page disappears
        oldPageIndexes.subtracting(currentPageIndexes).forEach {
            if let pageView = verso.getPageViewIfLoaded($0) as? PagedPublicationView.PageView {
                pageView.clearZoomImage(animated: false)
            }
        }
    }
    
    public func didEndZooming(pages pageIndexes: IndexSet, zoomScale: CGFloat, in verso: VersoView) {
        
        delegate?.didEndZooming(zoomScale: zoomScale)
        pageIndexes.forEach {
            if let pageView = verso.getPageViewIfLoaded($0) as? PagedPublicationView.PageView {
                pageView.startLoadingZoomImageIfNotLoaded()
            }
        }
        
        hotspotOverlayView.isZoomedIn = zoomScale > 1.0
    }
}
