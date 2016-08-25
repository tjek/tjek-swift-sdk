//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit



// All properties needed to render a publication view
@objc
public protocol PagedPublicationViewModelProtocol {
    
    // the background brand color of the publication
    var bgColor:UIColor { get }
    
    // expected total number of pages. 0 if unknown
    var pageCount:Int { get }
    
    // width/height ratio of pages in this publication. 0 if unknown
    var aspectRatio:Double { get }
    
    
    var isFetching:Bool { get }
}


@objc
public protocol PagedPublicationPageViewModelProtocol {
    
    var pageIndex:Int { get }
    
    var pageTitle:String? { get }
    
    var aspectRatio:Double { get }
    
    var defaultImageURL:NSURL? { get }
    
    var zoomImageURL:NSURL? { get }
    
    var hotspots:[PagedPublicationHotspotViewModelProtocol]? { get }
}


@objc
public protocol PagedPublicationHotspotViewModelProtocol {
    var data:AnyObject? { get }
    
    var boundingRect:CGRect { get }
}






// MARK: Concrete View Models


@objc (SGNPagedPublicationViewModel)
public class PagedPublicationViewModel : NSObject, PagedPublicationViewModelProtocol {
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

@objc (SGNPagedPublicationPageViewModel)
public class PagedPublicationPageViewModel : NSObject, PagedPublicationPageViewModelProtocol {
    public var pageIndex: Int
    
    public var pageTitle:String?
    public var aspectRatio: Double = 0
    
    public var defaultImage:UIImage?
    public var defaultImageURL:NSURL?
    
    public var zoomImageURL:NSURL?
    public var zoomImage:UIImage?
    
    
    public var hotspots:[PagedPublicationHotspotViewModelProtocol]?
    
    public init(pageIndex:Int, pageTitle:String?, aspectRatio:Double = 0, imageURL:NSURL? = nil, zoomImageURL:NSURL? = nil, hotspots:[PagedPublicationHotspotViewModelProtocol]? = nil) {
        self.pageIndex = pageIndex
        self.pageTitle = pageTitle
        self.aspectRatio = aspectRatio
        self.defaultImageURL = imageURL
        self.zoomImageURL = zoomImageURL
        self.hotspots = hotspots
    }
}


@objc (SGNPagedPublicationOfferHotspotViewModel)
public class PagedPublicationOfferHotspotViewModel : NSObject, PagedPublicationHotspotViewModelProtocol {
    public var data:AnyObject? = nil // TODO: cast as Offer obj?
    public var boundingRect: CGRect
    
    public init(rect:CGRect, data:AnyObject? = nil) {
        self.boundingRect = rect
        self.data = data
    }
}

