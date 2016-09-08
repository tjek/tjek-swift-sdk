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
        
        
        fetchPublicationData("efbbJc3", delay:0.2) { [weak self] (viewModel) in
            if let publication = viewModel {
                self?.publicationView.updateWithPublicationViewModel(publication)
                
//                self?.fetchPublicationHotspotData("efbbJc3", aspectRatio:publication.aspectRatio, delay:1.5) { [weak self] (viewModels) in
//                    self?.publicationView.updateHotspots(viewModels)
//                }
            }

        }
        fetchPublicationPageData("efbbJc3", delay:0.5) { [weak self] (viewModels) in
            self?.publicationView.updatePages(viewModels)
        }
        
//        let aspectRatio:Double = 647/962
//        let bgColor = UIColor(red:0.93, green:0.93, blue:0.93, alpha:1.00)
//        let pageCount = 22
//        let pubId = "902a2e3"
//        
//        
//        let viewModel = PagedPublicationViewModel(bgColor:bgColor, pageCount:pageCount, aspectRatio:aspectRatio)
//        publicationView.updateWithPublicationViewModel(viewModel)
//        
//        var pageModels = [PagedPublicationPageViewModel]()
//        for index in 0..<pageCount {
//            
////            let defaultUrl:NSURL? = nil
////            let zoomUrl:NSURL? = nil
//            
//            let defaultUrl = NSURL(string:"https://akamai.shopgun.com/img/catalog/view/\(pubId)-\(index+1).jpg")
//            let zoomUrl = NSURL(string:"https://akamai.shopgun.com/img/catalog/zoom/\(pubId)-\(index+1).jpg")
//            
//            let pageModel = PagedPublicationPageViewModel(pageIndex:index, pageTitle: "Page "+String(index), aspectRatio: aspectRatio, imageURL: defaultUrl, zoomImageURL: zoomUrl, hotspots: nil)
//            pageModels.append(pageModel)
//        }
//        
//        publicationView.updatePages(pageModels)
//        
        
        
        let dbltap = UITapGestureRecognizer(target: self, action: #selector(PDFViewController.didDoubleTap(_:)))
        dbltap.numberOfTapsRequired = 2
        
        self.view?.addGestureRecognizer(dbltap)
    }
    
    func didDoubleTap(gesture:UITapGestureRecognizer) {
        
        //        publicationView.jumpToPage()
    }
    
    
    func fetchPublicationData(publicationID:String, delay:NSTimeInterval = 0, completion:(PagedPublicationViewModel?)->Void) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_global_queue(0, 0)) {
            var viewModel:PagedPublicationViewModel? = nil
            
            if let filePath = NSBundle.mainBundle().pathForResource(publicationID, ofType:"json"),
                let data = NSData(contentsOfFile:filePath),
                let pubData = try? NSJSONSerialization.JSONObjectWithData(data, options:[]) as? NSDictionary {
                
                
                var bgColorStr:String = pubData?.valueForKeyPath("branding.pageflip.color") as? String ?? pubData?.valueForKeyPath("branding.color") as? String ?? "FF0000"
                if bgColorStr.hasPrefix("#") == false {
                    bgColorStr = "#"+bgColorStr
                }
                
                let bgColor = UIColor(rgba: bgColorStr)
                
                let pageCount:Int = pubData?.valueForKeyPath("page_count") as? Int ?? 0
                
                let width:CGFloat = pubData?.valueForKeyPath("dimensions.width") as? CGFloat ?? 1.0
                let height:CGFloat = pubData?.valueForKeyPath("dimensions.height") as? CGFloat ?? 1.0
                let aspectRatio:CGFloat = width > 0 && height > 0 ? width / height : 1.0
                
                
                viewModel = PagedPublicationViewModel(bgColor:bgColor, pageCount:pageCount, aspectRatio:aspectRatio)
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                completion(viewModel)
            }
        }
    }
    
    
    func fetchPublicationPageData(publicationID:String, delay:NSTimeInterval = 0, completion:([PagedPublicationPageViewModel]?)->Void) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_global_queue(0, 0)) {
            var viewModels:[PagedPublicationPageViewModel]? = nil
            
            if let filePath = NSBundle.mainBundle().pathForResource(publicationID+".pages", ofType:"json"),
                let data = NSData(contentsOfFile:filePath),
                let pagesData = try? NSJSONSerialization.JSONObjectWithData(data, options:[]) as? [[String:AnyObject]] {
                
                viewModels = []
                for (pageIndex,pageData) in pagesData!.enumerate() {
                    
                    var viewImageURL:NSURL?
                    var zoomImageURL:NSURL?
                    
                    if let urlStr = pageData["view"] as? String {
                        viewImageURL = NSURL(string: urlStr)
                    }
                    if let urlStr = pageData["zoom"] as? String {
                        zoomImageURL = NSURL(string: urlStr)
                    }
                    
                    
                    let pageModel = PagedPublicationPageViewModel(pageIndex:pageIndex, pageTitle: "Page "+String(pageIndex), aspectRatio: 0, imageURL: viewImageURL, zoomImageURL: zoomImageURL, hotspots: nil)
                    viewModels!.append(pageModel)
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(viewModels)
            }
        }
    }
    
    
    func fetchPublicationHotspotData(publicationID:String, aspectRatio:CGFloat, delay:NSTimeInterval = 0, completion:([PagedPublicationHotspotViewModel]?)->Void) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_global_queue(0, 0)) {
            var viewModels:[PagedPublicationHotspotViewModel]? = nil
            
            if let filePath = NSBundle.mainBundle().pathForResource(publicationID+".hotspots", ofType:"json"),
                let data = NSData(contentsOfFile:filePath),
                let hotspotsData = try? NSJSONSerialization.JSONObjectWithData(data, options:[]) as? [[String:AnyObject]] {
                
                viewModels = []
                for (_, hotspotData) in hotspotsData!.enumerate() {
                    
                    var pageRects:[Int:CGRect] = [:]
                    if let locationData = hotspotData["locations"] as? [String:[[CGFloat]]] {
                        for (pageIndexStr, coordList) in locationData {
                            
                            guard let pageIndex = Int(pageIndexStr) else {
                                continue
                            }
                            
                            var max:CGPoint?
                            var min:CGPoint?
                            
                            for coord in coordList {
                                guard coord.count == 2 else {
                                    max = nil
                                    min = nil
                                    break
                                }
                                
                                let x = coord[0]
                                let y = coord[1] * aspectRatio // we do this to convert out of the aweful old V2 coord system
                                
                                if max == nil {
                                    max = CGPoint(x:x, y:y)
                                }
                                else {
                                    if max!.x < x {
                                        max!.x = x
                                    }
                                    if max!.y < y {
                                        max!.y = y
                                    }
                                }
                                
                                if min == nil {
                                    min = CGPoint(x:x, y:y)
                                }
                                else {
                                    if min!.x > x {
                                        min!.x = x
                                    }
                                    if min!.y > y {
                                        min!.y = y
                                    }
                                }
                            }
                            
                            if min == nil || max == nil {
                                continue
                            }
                            
                            let rect = CGRect(origin: min!, size:CGSize(width: max!.x-min!.x, height: max!.y-min!.y))
                            
                            pageRects[pageIndex-1] = rect
                        }
                    }
                    
//                    let offerName:String = hotspotData["heading"] as? String ?? "?"
                    
//                    print("\(hotspotIndex): '\(offerName)' \(pageRects)\n")
                    
                    
//                    let hotspotModel = PagedPublicationHotspotViewModel(pageLocations: <#T##[Int : CGRect]#>, data: <#T##AnyObject?#>)
//                    viewModels!.append(hotspotModel)
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(viewModels)
            }
        }
    }
}