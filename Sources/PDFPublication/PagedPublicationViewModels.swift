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
    var aspectRatio:CGFloat { get }
    
    
    var isFetching:Bool { get }
}


@objc
public protocol PagedPublicationPageViewModelProtocol {
    
    var pageIndex:Int { get }
    
    var pageTitle:String? { get }
    
    var aspectRatio:CGFloat { get }
    
    var defaultImageURL:URL? { get }
    
    var zoomImageURL:URL? { get }
    
    var thumbImageURL:URL? { get }
}




// MARK: Concrete View Models


@objc (SGNPagedPublicationViewModel)
public class PagedPublicationViewModel : NSObject, PagedPublicationViewModelProtocol {
    public var bgColor: UIColor
    public var pageCount: Int = 0
    public var aspectRatio: CGFloat = 0
    
    public var isFetching: Bool
    
    
    public init(bgColor:UIColor, pageCount:Int = 0, aspectRatio:CGFloat = 0) {
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
    public var aspectRatio: CGFloat = 0
    
    public var defaultImage:UIImage?
    public var defaultImageURL:URL?
    
    public var zoomImageURL:URL?
    public var zoomImage:UIImage?
    
    public var thumbImageURL:URL?
    public var thumbImage:UIImage?
    
    public init(pageIndex:Int, pageTitle:String?, aspectRatio:CGFloat = 0, imageURL:URL? = nil, zoomImageURL:URL? = nil, thumbImageURL:URL? = nil) {
        self.pageIndex = pageIndex
        self.pageTitle = pageTitle
        self.aspectRatio = aspectRatio
        self.defaultImageURL = imageURL
        self.zoomImageURL = zoomImageURL
        self.thumbImageURL = thumbImageURL
    }
}



