//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

@objc (SGNPagedPublicationViewModel)
public class PagedPublicationViewModel : NSObject {
    public private(set) var uuid: String?
    
    /// the background brand color of the publication
    public private(set) var bgColor: UIColor
    
    /// expected total number of pages. 0 if unknown
    public private(set) var pageCount: Int = 0
    
    /// width/height ratio of pages in this publication. 0 if unknown
    public private(set) var aspectRatio: CGFloat = 0
    
    /// The date that this catalog expires.
    public private(set) var runTillDate: Date?
    
    public init(id:String? = nil, bgColor:UIColor, pageCount:Int = 0, aspectRatio:CGFloat = 0, runTillDate:Date? = nil) {
        self.uuid = id
        self.bgColor = bgColor
        self.pageCount = pageCount
        self.aspectRatio = aspectRatio
        self.runTillDate = runTillDate
    }
}

@objc (SGNPagedPublicationPageViewModel)
public class PagedPublicationPageViewModel : NSObject {
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



