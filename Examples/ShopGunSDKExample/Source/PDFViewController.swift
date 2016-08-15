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

class PDFViewController : PDFPublicationViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewModel = PDFPublicationViewModel(bgColor:UIColor.cyanColor(), pageCount:15, aspectRatio:1.2)
        updateWithPublicationViewModel(viewModel)
        
        var pageModels = [PDFPublicationPageViewModel]()
        for index in 0..<50 {
            
            let defaultUrl = NSURL(string:"https://akamai.shopgun.com/img/catalog/view/67e0X43-\(index+1).jpg?m=obbvh")
            let zoomUrl = NSURL(string:"https://akamai.shopgun.com/img/catalog/zoom/67e0X43-\(index+1).jpg?m=obbvh")
            
            let pageModel = PDFPublicationPageViewModel(pageIndex:UInt(index), pageTitle: "Page "+String(index), aspectRatio: 1.2, imageURL: defaultUrl, zoomImageURL: zoomUrl, hotspots: nil)
            pageModels.append(pageModel)
        }
        
        updatePages(pageModels)
    }
    
}