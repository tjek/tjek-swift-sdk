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


class ExampleViewController : UIViewController {
    
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
        
        reloadPublication(failPubRequest: true, failPageRequest: true)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            let bgColor = publicationView.backgroundColor ?? UIColor.white
            
            var white:CGFloat = 1
            bgColor.getWhite(&white, alpha: nil)
            return white > 0.6 ? .default : .lightContent
        }
    }
    
    func reloadPublication(failPubRequest:Bool = false, failPageRequest:Bool = false) {
        let publicationId = "efbbJc3"
        let bgColor:UIColor? = UIColor(red:0.01, green:0.18, blue:0.36, alpha:1.00)
        let pageCount:Int = 0
        let aspectRatio:CGFloat = 0
        let targetPageIndex:Int = 42
        
        let loader = LocalPublicationLoader(publicationId:publicationId,
                                            bgColor:bgColor,
                                            pageCount:pageCount,
                                            aspectRatio:aspectRatio)
        
        loader.failPublicationRequest = failPubRequest
        loader.failPageRequest = failPageRequest
        
        //        publicationView.reload(fromGraph:publicationId)
        publicationView.reload(with:loader, jumpTo:targetPageIndex)
    }
    
}

extension ExampleViewController : PagedPublicationViewDataSource {
    
    func outroViewClass(for pagedPublicationView:PagedPublicationView) -> (OutroView.Type)? {
        return ExampleOutroView.self
    }
//    func outroViewWidth(for pagedPublicationView: PagedPublicationView) -> CGFloat {
//        let size = pagedPublicationView.bounds.size
//        return size.width > size.height ? 0.7 : 0.8
//    }
    func configure(outroView:OutroView, for pagedPublicationView:PagedPublicationView) {
        guard let outro = outroView as? ExampleOutroView else {
            return
        }
        
        outro.layer.borderColor = UIColor.red.cgColor
        outro.layer.borderWidth = 1
    }
    
//    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String? {
//        return nil
//    }
    
    func errorView(with error:Error?, for pagedPublicationView:PagedPublicationView) -> UIView? {
        let errorView = ExampleErrorView()
        
        errorView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapErrorView(tap:))))
        
        errorView.backgroundColor = UIColor.red
        
        return errorView
    }

    public func didTapErrorView(tap:UITapGestureRecognizer) {
        reloadPublication()
//        reloadPublication(failPubRequest: true, failPageRequest: false)
//        reloadPublication(failPubRequest: false, failPageRequest: true)
    }
}

extension ExampleViewController : PagedPublicationViewDelegate {
    
    func didLongPress(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationHotspotViewModelProtocol], in pagedPublicationView: PagedPublicationView) {
        
        // debug page-jump when long-pressing
        var target = pageIndex + 10
        if target > pagedPublicationView.pageCount {
            target = target - pagedPublicationView.pageCount
        }
        pagedPublicationView.jump(toPageIndex: target, animated: true)
    }
    
    func didStartReloading(in pagedPublicationView:PagedPublicationView) {
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    func didLoad(publication publicationViewModel: PagedPublicationViewModelProtocol, in pagedPublicationView: PagedPublicationView) {
        self.setNeedsStatusBarAppearanceUpdate()
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

class ExampleErrorView : UIView {
    
    override open var intrinsicContentSize: CGSize {
        return CGSize(width:200, height:200)
    }
}
