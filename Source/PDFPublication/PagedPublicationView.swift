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

@objc(SGNPagedPublicationView)
public class PagedPublicationView : UIView {

    public override init(frame: CGRect) {
        super.init(frame:frame)
        
        
        // setup notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PagedPublicationView._didEnterBackgroundNotification(_:)), name: UIApplicationDidEnterBackgroundNotification, object: nil)        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PagedPublicationView._willEnterForegroundNotification(_:)), name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        
        backgroundColor = UIColor.whiteColor()
        
        verso.frame = frame
        verso.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        addSubview(verso)
        
        
        
        // FIXME: dont do this
        AlamofireImage.ImageDownloader.defaultURLCache().removeAllCachedResponses()
        if let imageCache = AlamofireImage.ImageDownloader.defaultInstance.imageCache as? AutoPurgingImageCache {
            print ("\(imageCache.memoryUsage) / \(imageCache.memoryCapacity)")
        }
        AlamofireImage.ImageDownloader.defaultInstance.imageCache?.removeAllImages()
        
    }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidEnterBackgroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillEnterForegroundNotification, object: nil)
    }
    
    
    
    
    // MARK: - Public
    
    
    // TODO: setting this will trigger changes
    public func updateWithPublicationViewModel(viewModel:PagedPublicationViewModelProtocol?) {
        
        publicationViewModel = viewModel
        
        verso.backgroundColor = viewModel?.bgColor
        
        // TODO: do we clear the pageviewmodels if this is updated again?
        
        // force a re-fetch of the pageCount
        verso.reloadPages()
    }
    
    public func updatePages(viewModels:[PagedPublicationPageViewModel]?) {
        
        pageViewModels = viewModels
        
        // force a re-fetch of the pageCount
        verso.reloadPages()
        
        // TODO: maybe just re-config the visible pages if pagecount didnt change?
    }
    
    
    public func updateHotspots(viewModels:[PagedPublicationHotspotViewModelProtocol]?) {
        
        // TODO: re-config the visible pages
    }
    
    
    
    
    
    

    // MARK: - Private properties
    
    private var publicationViewModel:PagedPublicationViewModelProtocol? = nil {
        didSet {
            
        }
    }
    private var pageViewModels:[PagedPublicationPageViewModel]? = nil {
        didSet {

        }
    }
    
    /// The indexes of active pages that havnt been loaded yet. This set changes when pages are activated and deactivated, and when images are loaded
    /// Used by the PagedPublicationPageViewDelegate methods
    private var activePageIndexesWithPendingLoadEvents = NSMutableIndexSet()
    
    /// the indexes of the pages that are loading their zoom images.
    /// This is reset whenever active pages change
    private var pageIndexesLoadingZoomImage = NSMutableIndexSet()
    
    lazy private var verso:VersoView = {
        let verso = VersoView()
        verso.dataSource = self
        verso.delegate = self
        return verso
    }()
    
    
    
    // MARK: Notification handlers
    func _didEnterBackgroundNotification(notification:NSNotification) {
        for pageIndex in verso.activePageIndexes {
            triggerEvent_PageDisappeared(pageIndex)
        }
    }
    func _willEnterForegroundNotification(notification:NSNotification) {
        for pageIndex in verso.activePageIndexes {
            _pageDidAppear(pageIndex)
        }
    }
    
}





// MARK: - VersoView DataSource

extension PagedPublicationView : VersoViewDataSource {

    public func pageCountForVerso(verso: VersoView) -> Int {
        return pageViewModels?.count ?? publicationViewModel?.pageCount ?? 0
    }
    
    public func configurePageForVerso(verso: VersoView, pageView: VersoPageView) {
        
        if let pubPage = pageView as? PagedPublicationPageView {
            
            let pageIndex = pubPage.pageIndex
            
            pubPage.delegate = self
            
            if let viewModel = pageViewModels?[safe:Int(pageIndex)] {
                
                // valid view model
                pubPage.configure(viewModel)
            }
                
            else
            {
                // build blank view model
                let viewModel = PagedPublicationPageViewModel(pageIndex:pageIndex, pageTitle:String(pageIndex+1), aspectRatio: publicationViewModel!.aspectRatio)
                
                pubPage.configure(viewModel)
            }
        }
    }
    
    public func pageViewClassForVerso(verso:VersoView) -> VersoPageViewClass {
        return PagedPublicationPageView.self
    }
    
    public func isVersoSinglePagedForSize(verso:VersoView, size:CGSize) -> Bool {
        
        // TODO: compare verso aspect ratio to publication aspect ratio
//        let versoAspectRatio = size.height > 0 ? size.width / size.height : 1
//        let isVersoPortrait = versoAspectRatio < 1
//        if let contentAspectRatio = publicationViewModel?.aspectRatio {
//
//        }
        return size.width <= size.height
    }
}

    



// MARK: - VersoView Delegate

extension PagedPublicationView : VersoViewDelegate {
    
    private func _pageDidAppear(pageIndex:Int) {
        
        // scrolling animation stopped and a new set of page Indexes are now visible.
        // trigger 'PAGE_APPEARED' event
        triggerEvent_PageAppeared(pageIndex)
        
        
        // if image loaded then trigger 'PAGE_LOADED' event
        if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
            where pageView.imageLoadState == .Loaded {
            
            triggerEvent_PageLoaded(pageIndex, fromCache: true)
        }
        else {
            // page became active but image hasnt yet loaded... keep track of it
            activePageIndexesWithPendingLoadEvents.addIndex(Int(pageIndex))
        }
    }
    
    public func activePagesDidChangeForVerso(verso: VersoView, activePageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {
        
        // go through all the newly added page indexes, triggering `appeared` (and possibly `loaded`) events
        for pageIndex in added {
            // scrolling animation stopped and a new set of page Indexes are now visible.
            
            _pageDidAppear(pageIndex)
        }
        
        // go through all the newly removed page indexes, triggering `disappeared` events and removing them from pending list
        for pageIndex in removed {
            activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
            
            // trigger a 'PAGE_DISAPPEARED event
            triggerEvent_PageDisappeared(pageIndex)

            
            // cancel the loading of the zoomimage
            if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView {
                pageView.clearZoomImage(animated: false)
            }
        }
    }
    
    public func visiblePagesDidChangeForVerso(verso: VersoView, visiblePageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {
        
        // TODO: start pre-warming images if we scroll past a certain point (and dont scroll back again within a time-frame)
//        print ("visible pages changed: \(visiblePageIndexes.arrayOfAllIndexes())")
    }
    
    
    public func didStartZoomingPagesForVerso(verso: VersoView, zoomingPageIndexes: NSIndexSet, zoomScale: CGFloat) {
        
        
//        print ("did start zooming \(zoomScale)")
    }
    
    public func didZoomPagesForVerso(verso: VersoView, zoomingPageIndexes: NSIndexSet, zoomScale: CGFloat) {
        
        
//        print ("did zoom \(zoomScale)")
    }
    
    public func didEndZoomingPagesForVerso(verso: VersoView, zoomingPageIndexes: NSIndexSet, zoomScale: CGFloat) {
        
        if zoomScale > 1 {
            
            for pageIndex in zoomingPageIndexes {
                if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PagedPublicationPageView
                    where pageView.zoomImageLoadState == .NotLoaded,
                    let zoomImageURL = pageViewModels?[safe:pageIndex]?.zoomImageURL {
                    
                    // started zooming on a page with no zoom-image loaded.
                    pageView.startLoadingZoomImageFromURL(zoomImageURL)
                    
                }
            }
        }
        
//        print ("did end zooming \(zoomScale)")
    }
    
}
    

    
    
    

    
// MARK: - PagedPublicationPage delegate

extension PagedPublicationView : PagedPublicationPageViewDelegate {
 
//    public func didConfigurePagedPublicationPage(pageView:PagedPublicationPageView, viewModel:PagedPublicationPageViewModelProtocol) {
//        
//    }
    
    public func didLoadPagedPublicationPageImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool) {
        
        let pageIndex = pageView.pageIndex
        
        if activePageIndexesWithPendingLoadEvents.containsIndex(pageIndex),
            let viewModel = pageViewModels?[safe:pageIndex] where viewModel.defaultImageURL == imageURL {
            
            // the page is active, and has not yet had its image loaded.
            // and the image url is the same as that of the viewModel at that page Index (view model hasnt changed since)
            // so trigger 'PAGE_LOADED' event
            // Only do this if the app is active - otherwise, when the app went into the background, we have sent a disappeared event
            if UIApplication.sharedApplication().applicationState == .Active {
                triggerEvent_PageLoaded(pageIndex, fromCache: fromCache)
            }
            
            activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
        }
    }
//    public func didLoadPagedPublicationPageZoomImage(pageView:PagedPublicationPageView, imageURL:NSURL, fromCache:Bool) {
//    
//    }
    
    public func didTapPagedPublicationPage(pageView: PagedPublicationPageView, location: CGPoint) {
        triggerEvent_PageTapped(pageView.pageIndex, location: location)
    }
//    public func didTouchPagedPublicationPage(pageView: PagedPublicationPageView, location: CGPoint) {
//    }
//    public func didStartLongPressPagedPublicationPage(pageView: PagedPublicationPageView, location: CGPoint, duration:NSTimeInterval) {
//    }
    public func didEndLongPressPagedPublicationPage(pageView: PagedPublicationPageView, location: CGPoint, duration:NSTimeInterval) {
        triggerEvent_PageLongPressed(pageView.pageIndex, location: location, duration:duration)
    }
}






// MARK: - Event Handling

// TODO: move to another file
extension PagedPublicationView {
    
    func triggerEvent_PageAppeared(pageIndex:Int) {
        print("[EVENT] Page Appeared(\(pageIndex))")
    }
    func triggerEvent_PageLoaded(pageIndex:Int,fromCache:Bool) {
        print("[EVENT] Page Loaded\(pageIndex) cache:\(fromCache)")
    }
    func triggerEvent_PageDisappeared(pageIndex:Int) {
        print("[EVENT] Page Disappeared(\(pageIndex))")
    }
    func triggerEvent_PagesChanged(fromPageIndexes:NSIndexSet, toPageIndexes:NSIndexSet) {
        // TODO: page Changed events
        print("[EVENT] Page Changed(\(fromPageIndexes.arrayOfAllIndexes()) -> \(toPageIndexes.arrayOfAllIndexes()))")
    }
    
    
    func triggerEvent_PageZoomedIn(pageIndexes:NSIndexSet, centerPoint:CGPoint) {
        print("[EVENT] Page Zoomed In(\(pageIndexes.arrayOfAllIndexes())) \(centerPoint)")
    }
    func triggerEvent_PageZoomedOut(pageIndexes:NSIndexSet, centerPoint:CGPoint) {
        print("[EVENT] Page Zoomed Out(\(pageIndexes.arrayOfAllIndexes())) \(centerPoint)")
    }
    
    
    func triggerEvent_PageTapped(pageIndex:Int, location:CGPoint) {
        print("[EVENT] Page Tapped(\(pageIndex)) \(location)")
    }
    func triggerEvent_PageLongPressed(pageIndex:Int, location:CGPoint, duration:NSTimeInterval) {
        print("[EVENT] Page LongPressed(\(pageIndex)) \(location)")
    }
}


//enum PagedPublicationEventType {
//    case Opened(id:String, pageNumber:Int, pageCount:Int)
//    
//    
//    // TODO: func to get properties dict & type name
//}












// MARK: - Fetching
// TODO: move to another file
public extension PagedPublicationView {
    
    // uses graphKit to fetch the PagedPublication for the specified publicationId
    public func fetchContents(publicationId:String) {
        // put it in a `fetching` state
        
        
        
        // TODO: perform the request with GraphKit
        
        // TODO: update publicationVM
//        updateWithPublicationViewModel(nil)
        
    }
    
}




// Debug utilty for printing out indexSets
extension NSIndexSet {
    func arrayOfAllIndexes() -> [Int] {
        var allIndexes = [Int]()
        enumerateIndexesUsingBlock { (idx, stop) in
            allIndexes.append(idx)
        }
        return allIndexes
    }
}
