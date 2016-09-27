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
        
        fetchPublicationData(publicationId, delay:0.2) { [weak self] (viewModel) in
            if let publication = viewModel {
                
                self?.publicationView.update(publication: publication, targetPageIndex:publication.pageCount-1)
                
                self?.setNeedsStatusBarAppearanceUpdate()
                
                fetchPublicationHotspotData(publicationId, aspectRatio:publication.aspectRatio, delay:1.5) { [weak self] (viewModels) in
                    self?.publicationView.update(hotspots:viewModels)
                }
            }

        }
        fetchPublicationPageData(publicationId, delay:0.5) { [weak self] (viewModels) in
            self?.publicationView.update(pages:viewModels)
        }
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
