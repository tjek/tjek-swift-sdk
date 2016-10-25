//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

import Kingfisher
import ShopGunSDK


class PDFViewController : UIViewController {
    
    lazy var publicationView:PagedPublicationView = {
        let view = PagedPublicationView()
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // FIXME: dont do this
        KingfisherManager.shared.cache.clearDiskCache()
        KingfisherManager.shared.cache.clearMemoryCache()
        
        
        publicationView.frame = view.frame
        publicationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(publicationView)
        
        let publicationId = "efbbJc3"
//        publicationView.reload(publicationId:publicationId)
        let bgColor:UIColor? = nil //UIColor(red:0.01, green:0.18, blue:0.36, alpha:1.00)
        let pageCount:Int = 0
        
        publicationView.reload(with:LocalPublicationLoader(publicationId:publicationId,
                                                           preloadedBackgroundColor:bgColor,
                                                           preloadedPageCount:pageCount),
                               targetPageIndex:12)
        
        
        /* public interface:
         
         publicationView.reload(publicationId)
         publicationView.reload(publicationId, targetPageIndex:2)
         publicationView.reload(publicationId, backgroundColor:nil, pageCount:nil, targetPageIndex:2)
            -> calls configureBasics w/ target page index
                -> updates bg color
                -> triggers verso page reload
            -> builds a default graph loader (giving publicationID) (or maybe have loader class query in delegate)
            -> calls reload with that loader:
         publicationView.reload(loader:<>, targetPageIndex:2)
            -> asks loader to start loading
            -> on publication completion, loader callback triggers configureBasics w/ target page index (see above)
            -> on pages completion, calls configurePages
         
         
         
         
        */
        /*
            create loader with pubID (and viewmodel?)
            
            set loader as pubview datasource
         
            set pubiew bgcolor, if known
         
         
            pubview.reloadPages() -> asks datasource
            
            pubview.setLoading() -> show spinner
         
         
         
         */
        
        
        
        
//        publicationView.reload(with: PagedPublicationGraphLoader())
        
//        fetchPublicationData(publicationId, delay:0.2) { [weak self] (viewModel) in
//            if let publication = viewModel {
//                
//                self?.publicationView.update(publication: publication, targetPageIndex:publication.pageCount-1)
//                
//                self?.setNeedsStatusBarAppearanceUpdate()
//                
//                fetchPublicationHotspotData(publicationId, aspectRatio:publication.aspectRatio, delay:1.5) { [weak self] (viewModels) in
//                    self?.publicationView.update(hotspots:viewModels)
//                }
//            }
//
//        }
//        fetchPublicationPageData(publicationId, delay:0.5) { [weak self] (viewModels) in
//            self?.publicationView.update(pages:viewModels)
//        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            let bgColor = publicationView.backgroundColor ?? UIColor.white
            
            var white:CGFloat = 1
            bgColor.getWhite(&white, alpha: nil)
            return white > 0.6 ? .default : .lightContent
        }
    }
    
}

extension PDFViewController : PagedPublicationViewDataSource {
    
//    public func pageCount(for pagedPublicationView: PagedPublicationView) -> Int {
//        return 0
//    }
//    
//    public func hotspotViewModels(on pageIndex: Int, for pagedPublicationView: PagedPublicationView) -> [PagedPublicationHotspotViewModelProtocol] {
//        return []
//    }
//
//    public func pageViewModel(at pageIndex: Int, for pagedPublicationView: PagedPublicationView) -> PagedPublicationPageViewModel? {
//        return nil
//    }

    
    func outroViewClass(pagedPublicationView: PagedPublicationView, size: CGSize) -> (OutroView.Type)? {
        return ExampleOutroView.self
    }
//    func outroViewWidth(pagedPublicationView: PagedPublicationView, size: CGSize) -> CGFloat {
//        return size.width > size.height ? 0.7 : 0.8
//    }
    func configureOutroView(pagedPublicationView: PagedPublicationView, outroView: OutroView) {
        guard let outro = outroView as? ExampleOutroView else {
            return
        }
        
        outro.layer.borderColor = UIColor.red.cgColor
        outro.layer.borderWidth = 1
    }
    
//    func textForPageNumberLabel(pagedPublicationView: PagedPublicationView, pageIndexes: IndexSet, pageCount: Int) -> String? {
//        return nil
//    }
    
    func errorView(for error:Error?, in pagedPublicationView:PagedPublicationView) -> UIView? {
        let errorView = UIView()
        errorView.frame = CGRect(origin:CGPoint.zero, size:CGSize(width: 200, height: 200))
        errorView.backgroundColor = UIColor.red
        
        return errorView
    }

}

extension PDFViewController : PagedPublicationViewDelegate {
    func didLongPressPage(pagedPublicationView: PagedPublicationView, pageIndex: Int, locationInPage: CGPoint, hotspots: [PagedPublicationHotspotViewModelProtocol]) {
        
        // debug page-jump when long-pressing
        var target = pageIndex + 10
        if target > pagedPublicationView.pageCount {
            target = target - pagedPublicationView.pageCount
        }
        pagedPublicationView.jump(toPageIndex: target, animated: true)
    }
    

}


class ExampleOutroView : OutroView {
    required init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor.green
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
