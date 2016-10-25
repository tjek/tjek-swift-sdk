//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

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




/// This is a loader that fetches the reader view models from the v2 API
class LocalPublicationLoader : NSObject, PagedPublicationLoaderProtocol {
    
    public var publicationId: String
    public var preloadedBackgroundColor:UIColor?
    public var preloadedPageCount:Int = 0
    
    
    convenience init(publicationId:String) {
        self.init(publicationId: publicationId, preloadedBackgroundColor:nil, preloadedPageCount:0)
    }
    init(publicationId:String, preloadedBackgroundColor:UIColor?, preloadedPageCount:Int) {
        self.publicationId = publicationId
        self.preloadedBackgroundColor = preloadedBackgroundColor
        self.preloadedPageCount = preloadedPageCount
    }
    
    
    public func load(publicationLoaded:@escaping PagedPublicationLoaderProtocol.PublicationLoadedHandler,
                     pagesLoaded:@escaping PagedPublicationLoaderProtocol.PagesLoadedHandler,
                     hotspotsLoaded:@escaping PagedPublicationLoaderProtocol.HotspotsLoadedHandler) {
        
        
        let publicationIdToFetch = self.publicationId
        
        LocalPublicationLoader.fetchPublicationData(publicationIdToFetch, delay:1.2) { (loadedPublication) in
            
            publicationLoaded(loadedPublication, nil)
            
            
            if let publication = loadedPublication {
                LocalPublicationLoader.fetchPublicationHotspotData(publicationIdToFetch, aspectRatio:publication.aspectRatio, delay:1.5) { (loadedHotspots) in
                    hotspotsLoaded(loadedHotspots, nil)
                }
            }
        }
        
        
        LocalPublicationLoader.fetchPublicationPageData(publicationIdToFetch, delay:2.5) { (loadedPages) in
            pagesLoaded(loadedPages, nil)
        }
    }
    
    
    
    
    // MARK: Local fetching/parsing methods
    
    static func fetchPublicationData(_ publicationID:String, delay:TimeInterval = 0, completion:@escaping (PagedPublicationViewModelProtocol?)->Void) {
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            var viewModel:PagedPublicationViewModelProtocol? = nil
            
            if let filePath = Bundle.main.path(forResource: publicationID, ofType:"json"),
                let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                let pubData = try? JSONSerialization.jsonObject(with: data, options:[]) as? NSDictionary {
                
                
                var bgColorStr:String = pubData?.value(forKeyPath: "branding.pageflip.color") as? String ?? pubData?.value(forKeyPath: "branding.color") as? String ?? "FF0000"
                if bgColorStr.hasPrefix("#") == false {
                    bgColorStr = "#"+bgColorStr
                }
                
                let bgColor = UIColor(rgba: bgColorStr)
                
                let pageCount:Int = pubData?.value(forKeyPath: "page_count") as? Int ?? 0
                
                let width:CGFloat = pubData?.value(forKeyPath: "dimensions.width") as? CGFloat ?? 1.0
                let height:CGFloat = pubData?.value(forKeyPath: "dimensions.height") as? CGFloat ?? 1.0
                let aspectRatio:CGFloat = width > 0 && height > 0 ? width / height : 1.0
                
                
                viewModel = PagedPublicationViewModel(uuid:publicationID, bgColor:bgColor, pageCount:pageCount, aspectRatio:aspectRatio)
            }
            
            DispatchQueue.main.async {
                completion(viewModel)
            }
        }
    }
    
    
    static func fetchPublicationPageData(_ publicationID:String, delay:TimeInterval = 0, completion:@escaping ([PagedPublicationPageViewModelProtocol]?)->Void) {
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            var viewModels:[PagedPublicationPageViewModelProtocol]? = nil
            
            if let filePath = Bundle.main.path(forResource: publicationID+".pages", ofType:"json"),
                let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                let pagesData = try? JSONSerialization.jsonObject(with: data, options:[]) as? [[String:AnyObject]] {
                
                viewModels = []
                for (pageIndex,pageData) in pagesData!.enumerated() {
                    
                    var viewImageURL:URL?
                    var zoomImageURL:URL?
                    
                    if let urlStr = pageData["view"] as? String {
                        viewImageURL = URL(string: urlStr)
                    }
                    if let urlStr = pageData["zoom"] as? String {
                        zoomImageURL = URL(string: urlStr)
                    }
                    
                    
                    let pageModel = PagedPublicationPageViewModel(pageIndex:pageIndex, pageTitle: String(pageIndex+1), aspectRatio: 0, viewImageURL: viewImageURL, zoomImageURL: zoomImageURL)
                    viewModels!.append(pageModel)
                }
            }
            DispatchQueue.main.async {
                completion(viewModels)
            }
        }
    }
    
    
    static func fetchPublicationHotspotData(_ publicationID:String, aspectRatio:CGFloat, delay:TimeInterval = 0, completion:@escaping ([PagedPublicationHotspotViewModelProtocol]?)->Void) {
    
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            var viewModels:[PagedPublicationHotspotViewModelProtocol]? = nil
    
            if let filePath = Bundle.main.path(forResource: publicationID+".hotspots", ofType:"json"),
                let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                let hotspotsData = try? JSONSerialization.jsonObject(with: data, options:[]) as? [[String:AnyObject]] {
    
                viewModels = []
                for (_, hotspotData) in hotspotsData!.enumerated() {
    
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
    
                    let hotspotModel = PagedPublicationEmptyHotspotViewModel(pageLocations: pageRects)
                    viewModels!.append(hotspotModel)
                }
            }
            DispatchQueue.main.async {
                completion(viewModels)
            }
        }
    }
}
