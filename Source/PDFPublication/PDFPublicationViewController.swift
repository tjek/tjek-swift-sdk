//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


enum PDFPublicationEventType {
    case Opened(id:String, pageNumber:Int, pageCount:Int)
    
    
    // TODO: func to get properties dict & type name
}

/*
 
 **opened-pdf-publication**
 
 * id<String>
 * pageNumber<Integer>
 * pageCount<Integer>
 
 
 **saw-pdf-publication-page**
 
 * id<String>
 * pageNumbers<Array<Integer>>
 * pageCount<Integer>
 * msSpent<Integer>
 
 
 **zoomed-pdf-publication-page**
 
 * id<String>
 * pageNumbers<Array<Integer>>
 * pageCount<Integer>
 * msSpent<Integer>
 
 
 **clicked-pdf-publication-hotspot**
 
 * id<String>
 * pageNumber<Integer>
 * type<String>
 
 
 **clicked-pdf-publication-page**
 
 * id<String>
 * pageNumber<Integer>
 * x<Integer>
 * y<Integer>
 
 

 */

//public typealias ImageLoaderFetchCompletionHandler = (url:NSURL, image:UIImage?)->Void
public protocol PDFPublicationImageLoader {
    func fetchImageForURL(url:NSURL, success:(UIImage)->Void, failure:(NSError)->Void)
}



// All properties needed to render a publication view
public protocol PDFPublicationViewModelProtocol {
    
    // the background brand color of the publication
    var bgColor:UIColor { get }
    
    // expected total number of pages. 0 if unknown
    var pageCount:Int { get }
    
    // width/height ratio of pages in this publication. 0 if unknown
    var aspectRatio:Double { get }
    
    
    
    var isFetching:Bool { get }
    
    
//    var pages:[PDFPublicationPageViewModelProtocol] { get }
}



public protocol PDFPublicationHotspotViewModelProtocol {
    var data:AnyObject? { get }
    
    var boundingRect:CGRect { get }
}



@objc(SGNPDFPublicationViewController)
public class PDFPublicationViewController : UIViewController {

    private var publicationViewModel:PDFPublicationViewModelProtocol? = nil {
        didSet {
            
        }
    }
    private var pageViewModels:[PDFPublicationPageViewModel]? = nil {
        didSet {

        }
    }
    
    
    
    lazy var verso:VersoView<PDFPublicationViewController> = {
        let view = VersoView<PDFPublicationViewController>()
        view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.dataSource = self
        view.delegate = self
        
//        view.pageLayout = VersoGridLayout()
        
        return view
    }()
    

    private var imageLoader:PDFPublicationImageLoader = BasicImageLoader()









    public override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        updateLayoutForSize(size)
    }
    
    
    
    
    
    
    
    
    
    // TODO: setting this will trigger changes
    public func updateWithPublicationViewModel(viewModel:PDFPublicationViewModelProtocol?) {
        
        publicationViewModel = viewModel
        
        verso.backgroundColor = viewModel?.bgColor
        
        // force a re-fetch of the pageCount
        verso.reloadPages(animated: false)
        
        
        
//        if let vm = publicationViewModel {
//            
//            dispatch_async(dispatch_get_main_queue()) {
//                
//                self.collectionView.backgroundColor = vm.bgColor
//                
//                
//            }
//        } else {
//            
//            // empty view model - what does that mean? blank white screen?
//            
//        }
    }
    
    public func updatePages(viewModels:[PDFPublicationPageViewModel]?) {
        
        pageViewModels = viewModels
        
        verso.reloadPages(animated: true)
    }

    
    public func updateHotspots(viewModels:[PDFPublicationHotspotViewModelProtocol]?) {
        
    }
  
    
    
    
    
    
    
    
    
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // FIXME: dont do this
        UIImageView.af_sharedImageDownloader.imageCache?.removeAllImages()
        
        
        view.backgroundColor = UIColor.whiteColor()
        
        verso.frame = view.frame
        view.addSubview(verso)

        
        updateLayoutForSize(verso.frame.size)
    }
    
    
    
    
    
    
    private func updateLayoutForSize(size:CGSize) {
        let screenAspectRatio = size.height > 0 ? size.width / size.height : 1
        let isScreenPortrait = screenAspectRatio < 1
        
        // TODO: compare to publication aspect ratio
//        if let contentAspectRatio = publicationViewModel?.aspectRatio {
//        
//        }
        
        if let pagedLayout = verso.pageLayout as? VersoPagedLayout {
            pagedLayout.singlePageMode = isScreenPortrait
        }
    }

    
    
    
    
    
    
    
    /// The indexes of active pages that havnt been loaded yet. This set changes when pages are activated and deactivated, and when images are loaded
    private var _activePageIndexesWithPendingLoadEvents = NSMutableIndexSet()
    
}


extension PDFPublicationViewController : VersoViewDataSource {
    
    public typealias VersoPageType = PDFPublicationPageCell
    
    public func numberOfPagesInVerso() -> UInt {
        return UInt(pageViewModels?.count ?? publicationViewModel?.pageCount ?? 0)
    }
    
    public func configureVersoPage(page:PDFPublicationPageCell, pageIndex:UInt) {
        
        page.pageContentsView?.delegate = self
        
        // valid view model
        if let viewModel = pageViewModels?[safe:Int(pageIndex)] {
            
            page.configure(viewModel)
        }
            
        else
        {
            // build blank view model
            let viewModel = PDFPublicationPageViewModel(pageIndex:pageIndex, pageTitle:String(pageIndex), aspectRatio: publicationViewModel!.aspectRatio)
            
            page.configure(viewModel)
        }
    }
}


extension PDFPublicationViewController : PDFPublicationPageContentsViewDelegate {
    
    public func didConfigurePDFPageContents(pageIndex: UInt, viewModel: PDFPublicationPageViewModelProtocol) {
        print("didConfig page: \(pageIndex)")
    }
    
    public func didLoadPDFPageContentsImage(pageIndex: UInt, imageURL:NSURL, fromCache: Bool) {
        
        if _activePageIndexesWithPendingLoadEvents.containsIndex(Int(pageIndex)),
            let viewModel = pageViewModels?[safe:Int(pageIndex)] where viewModel.defaultImageURL == imageURL {
            
            // the page is active, and has not yet had its image loaded.
            // and the image url is the same as that of the viewModel at that page Index (view model hasnt changed since)
            // so trigger 'PAGE_LOADED' event
            
            triggerEvent_PageLoaded(pageIndex, fromCache: fromCache)
            
            _activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
        }
    }
}


extension PDFPublicationViewController : VersoViewDelegate {
    
    public func versoPageDidBecomeActive(pageIndex:UInt) {
        
        // scrolling animation stopped and a new set of page Indexes are now visible.
        // trigger 'PAGE_APPEARED' event
        triggerEvent_PageAppeared(pageIndex)
        
        
        // if image loaded then trigger 'PAGE_LOADED' event
        if let pageContentsView = verso.visiblePageView(pageIndex)?.pageContentsView
            where pageContentsView.isImageLoaded {
            
            triggerEvent_PageLoaded(pageIndex, fromCache: true)
        }
        else {
            // page became active but image hasnt het loaded... keep track of it
            _activePageIndexesWithPendingLoadEvents.addIndex(Int(pageIndex))
        }
    }
    public func versoPageDidBecomeInactive(pageIndex:UInt) {
        _activePageIndexesWithPendingLoadEvents.removeIndex(Int(pageIndex))
        
        // trigger a 'PAGE_DISAPPEARED event
        triggerEvent_PageDisappeared(pageIndex)
    }

    public func versoVisiblePagesDidChange(pageIndexes:NSIndexSet) {
        
//        for visibleIndex in pageIndexes {
//            
//            if let viewModel = pageViewModels?[safe:Int(visibleIndex)],
//                let imageURL = viewModel.defaultImageURL where
//                viewModel.defaultImage == nil && viewModel.zoomImage == nil {
            
                
                // view model has no images - set from image loader
//                imageLoader.fetchImageForURL(imageURL) { (url, image) in
//                    if let img = image {
//                        dispatch_async(dispatch_get_main_queue()) {
//                            viewModel.defaultImage = img
//                            
//                            self.verso.refreshPagesIfVisible(NSIndexSet(index:visibleIndex))
//                        }
//                    }
//                }
//            }
//        }
//        
    }
}



// Mark: - EVENTS
extension PDFPublicationViewController {
    
    func triggerEvent_PageAppeared(pageIndex:UInt) {
        print("[EVENT] Page Appeared \(pageIndex)")
    }
    func triggerEvent_PageLoaded(pageIndex:UInt,fromCache:Bool) {
        print("[EVENT] Page Loaded \(pageIndex) cache:\(fromCache)")
    }
    func triggerEvent_PageDisappeared(pageIndex:UInt) {
        print("[EVENT] Page Disappeared \(pageIndex)")
    }
    
}

















// MARK: View Models

@objc (SGNPDFPublicationViewModel)
public class PDFPublicationViewModel : NSObject, PDFPublicationViewModelProtocol {
    public var bgColor: UIColor
    public var pageCount: Int = 0
    public var aspectRatio: Double = 0
    
    public var isFetching: Bool
    
    
    public init(bgColor:UIColor, pageCount:Int = 0, aspectRatio:Double = 0) {
        self.bgColor = bgColor
        self.pageCount = pageCount
        self.aspectRatio = aspectRatio
        
        self.isFetching = false
    }
}

@objc (SGNPDFPublicationPageViewModel)
public class PDFPublicationPageViewModel : NSObject, PDFPublicationPageViewModelProtocol {
    public var pageIndex: UInt
    
    public var pageTitle:String?
    public var aspectRatio: Double = 0
    
    public var defaultImage:UIImage?
    public var defaultImageURL:NSURL?
    
    public var zoomImageURL:NSURL?
    public var zoomImage:UIImage?
    
    
    public var hotspots:[PDFPublicationHotspotViewModelProtocol]?
    
    public init(pageIndex:UInt, pageTitle:String?, aspectRatio:Double = 0, imageURL:NSURL? = nil, zoomImageURL:NSURL? = nil, hotspots:[PDFPublicationHotspotViewModelProtocol]? = nil) {
        self.pageIndex = pageIndex
        self.pageTitle = pageTitle
        self.aspectRatio = aspectRatio
        self.defaultImageURL = imageURL
        self.zoomImageURL = zoomImageURL
        self.hotspots = hotspots
    }
}


@objc (SGNPDFPublicationOfferHotspotViewModel)
public class PDFPublicationOfferHotspotViewModel : NSObject, PDFPublicationHotspotViewModelProtocol {
    public var data:AnyObject? = nil // TODO: cast as Offer obj?
    public var boundingRect: CGRect
    
    public init(rect:CGRect, data:AnyObject? = nil) {
        self.boundingRect = rect
        self.data = data
    }
}



public extension PDFPublicationViewController {
    
    // uses graphKit to fetch the PDFPublication for the specified publicationId
    public func fetchContents(publicationId:String) {
        // put it in a `fetching` state
        
        
        
        // TODO: perform the request with GraphKit
        
        // TODO: update publicationVM
//        updateWithPublicationViewModel(nil)
        
    }
    
}



class BasicImageLoader : PDFPublicationImageLoader {
    func fetchImageForURL(url:NSURL, success:(UIImage)->Void, failure:(NSError)->Void) {
//        let session = NSURLSession.sharedSession()
//        
////        let req = NSMutableURLRequest(URL: url)
////        let task = session.dataTaskWithRequest(req) { (data, response, error) in
////            
////            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC)))
////            , dispatch_get_main_queue()) {
////                if data != nil,
////                    let image = UIImage(data: data!) {
////                    completion(url: url, image: image)
////                }
////                else {
////                    completion(url: url, image: nil)
////                }
////            }
//        }
//        task.resume()
    }
}

