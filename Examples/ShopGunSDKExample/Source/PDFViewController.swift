//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

import ShopGunSDK

class PDFViewController : UIViewController {
    
    lazy var publicationView:PagedPublicationView = {
        let view = PagedPublicationView()

        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        publicationView.frame = view.frame
        publicationView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(publicationView)
        
        
        
        
        let aspectRatio:Double = 647/962
        let bgColor = UIColor(red:0.93, green:0.93, blue:0.93, alpha:1.00)
        let pageCount = 22
        let pubId = "902a2e3"
        
        
        let viewModel = PagedPublicationViewModel(bgColor:bgColor, pageCount:pageCount, aspectRatio:aspectRatio)
        publicationView.updateWithPublicationViewModel(viewModel)
        
        var pageModels = [PagedPublicationPageViewModel]()
        for index in 0..<pageCount {
            
//            let defaultUrl:NSURL? = nil
//            let zoomUrl:NSURL? = nil
            
            let defaultUrl = NSURL(string:"https://akamai.shopgun.com/img/catalog/view/\(pubId)-\(index+1).jpg")
            let zoomUrl = NSURL(string:"https://akamai.shopgun.com/img/catalog/zoom/\(pubId)-\(index+1).jpg")
            
            let pageModel = PagedPublicationPageViewModel(pageIndex:index, pageTitle: "Page "+String(index), aspectRatio: aspectRatio, imageURL: defaultUrl, zoomImageURL: zoomUrl, hotspots: nil)
            pageModels.append(pageModel)
        }
        
        publicationView.updatePages(pageModels)
        
        
        
        let dbltap = UITapGestureRecognizer(target: self, action: #selector(PDFViewController.didDoubleTap(_:)))
        dbltap.numberOfTapsRequired = 2
        
        self.view?.addGestureRecognizer(dbltap)
    }
    
    func didDoubleTap(gesture:UITapGestureRecognizer) {
        
//        publicationView.jumpToPage()
    }
    
}