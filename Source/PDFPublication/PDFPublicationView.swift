//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit



@objc(SGNPDFPublicationView)
public class PDFPublicationView : UIView {

    public override init(frame: CGRect) {
        super.init(frame:frame)
        
        backgroundColor = UIColor.whiteColor()
        
        verso.frame = frame
        verso.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        addSubview(verso)
        
        // FIXME: dont do this
        UIImageView.af_sharedImageDownloader.imageCache?.removeAllImages()
        
    }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    
    
    
    // MARK: - Public
    
    
    // TODO: setting this will trigger changes
    public func updateWithPublicationViewModel(viewModel:PDFPublicationViewModelProtocol?) {
        
        publicationViewModel = viewModel
        
        verso.backgroundColor = viewModel?.bgColor
        
        // force a re-fetch of the pageCount
        verso.reloadPages()
    }
    
    public func updatePages(viewModels:[PDFPublicationPageViewModel]?) {
        
        pageViewModels = viewModels
        
        // force a re-fetch of the pageCount
        verso.reloadPages()
        
        // TODO: maybe just re-config the visible pages if pagecount didnt change?
    }
    
    
    public func updateHotspots(viewModels:[PDFPublicationHotspotViewModelProtocol]?) {
        
        // TODO: re-config the visible pages
    }
    
    
    
    
    
    

    // MARK: - Private properties
    
    private var publicationViewModel:PDFPublicationViewModelProtocol? = nil {
        didSet {
            
        }
    }
    private var pageViewModels:[PDFPublicationPageViewModel]? = nil {
        didSet {

        }
    }
    
    /// The indexes of active pages that havnt been loaded yet. This set changes when pages are activated and deactivated, and when images are loaded
    /// Used by the PDFPublicationPageViewDelegate methods
    private var activePageIndexesWithPendingLoadEvents = NSMutableIndexSet()
    
    
    lazy private var verso:VersoView = {
        let verso = VersoView()
        verso.dataSource = self
        verso.delegate = self
        return verso
    }()
    
    
}





// MARK: - VersoView DataSource

extension PDFPublicationView : VersoViewDataSource {

    public func pageCountForVerso(verso: VersoView) -> Int {
        return pageViewModels?.count ?? publicationViewModel?.pageCount ?? 0
    }
    
    public func configurePageForVerso(verso: VersoView, pageView: VersoPageView) {
        
        if let pubPage = pageView as? PDFPublicationPageView {
            
            let pageIndex = pubPage.pageIndex
            print ("Configuring \(pageIndex)")
            
            pubPage.delegate = self
                
            // valid view model
            if let viewModel = pageViewModels?[safe:Int(pageIndex)] {
                
                pubPage.configure(viewModel)
            }
                
            else
            {
                // build blank view model
                let viewModel = PDFPublicationPageViewModel(pageIndex:pageIndex, pageTitle:String(pageIndex), aspectRatio: publicationViewModel!.aspectRatio)
                
                pubPage.configure(viewModel)
            }
        }
    }
    
    public func pageViewClassForVerso(verso:VersoView) -> VersoPageViewClass {
        return PDFPublicationPageView.self
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

extension PDFPublicationView : VersoViewDelegate {
    
    public func activePagesDidChangeForVerso(verso: VersoView, activePageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {
        
        // go through all the newly added page indexes, triggering `appeared` (and possibly `loaded`) events
        for pageIndex in added {
            // scrolling animation stopped and a new set of page Indexes are now visible.
            // trigger 'PAGE_APPEARED' event
            triggerEvent_PageAppeared(pageIndex)
            
            
            // if image loaded then trigger 'PAGE_LOADED' event
            if let pageView = verso.getPageViewIfLoaded(pageIndex) as? PDFPublicationPageView
                where pageView.isImageLoaded {
                
                triggerEvent_PageLoaded(pageIndex, fromCache: true)
            }
            else {
                // page became active but image hasnt het loaded... keep track of it
                activePageIndexesWithPendingLoadEvents.addIndex(Int(pageIndex))
            }
        }
        
        // go through all the newly removed page indexes, triggering `disappeared` events and removing them from pending list
        for pageIndex in removed {
            activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
            
            // trigger a 'PAGE_DISAPPEARED event
            triggerEvent_PageDisappeared(pageIndex)
        }
    }
    
    public func visiblePagesDidChangeForVerso(verso: VersoView, visiblePageIndexes: NSIndexSet, added: NSIndexSet, removed: NSIndexSet) {
        
        // TODO: start pre-warming images if we scroll past a certain point (and dont scroll back again within a time-frame)
//        print ("visible pages changed: \(visiblePageIndexes.arrayOfAllIndexes())")
    }
    
}
    

    
    
    

    
// MARK: - PDFPublicationPage delegate

extension PDFPublicationView : PDFPublicationPageViewDelegate {
 
    public func didConfigurePDFPageContents(pageIndex: Int, viewModel: PDFPublicationPageViewModelProtocol) {
        //        print("didConfig page: \(pageIndex)")
    }
    
    public func didLoadPDFPageContentsImage(pageIndex: Int, imageURL:NSURL, fromCache: Bool) {
        
        if activePageIndexesWithPendingLoadEvents.containsIndex(Int(pageIndex)),
            let viewModel = pageViewModels?[safe:Int(pageIndex)] where viewModel.defaultImageURL == imageURL {
            
            // the page is active, and has not yet had its image loaded.
            // and the image url is the same as that of the viewModel at that page Index (view model hasnt changed since)
            // so trigger 'PAGE_LOADED' event
            
            triggerEvent_PageLoaded(pageIndex, fromCache: fromCache)
            
            activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
        }
    }
    
}






// MARK: - Event Handling

// TODO: move to another file
extension PDFPublicationView {
    
    func triggerEvent_PageAppeared(pageIndex:Int) {
        print("[EVENT] Page Appeared(\(pageIndex))")
    }
    func triggerEvent_PageLoaded(pageIndex:Int,fromCache:Bool) {
        print("[EVENT] Page Loaded \(pageIndex) cache:\(fromCache)")
    }
    func triggerEvent_PageDisappeared(pageIndex:Int) {
        print("[EVENT] Page Disappeared(\(pageIndex))")
    }
    
}


//enum PDFPublicationEventType {
//    case Opened(id:String, pageNumber:Int, pageCount:Int)
//    
//    
//    // TODO: func to get properties dict & type name
//}












// MARK: - Fetching
// TODO: move to another file
public extension PDFPublicationView {
    
    // uses graphKit to fetch the PDFPublication for the specified publicationId
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
