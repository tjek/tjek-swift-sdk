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
    
    /// The date the publication becomes available
    public private(set) var runFromDate: Date?
    
    /// The date that this publication expires.
    public private(set) var runTillDate: Date?
    
    public private(set) var coverThumbImage:URL?
    
    public private(set) var dealerId: String?
    public private(set) var dealerName: String?
    
    public init(id:String? = nil, bgColor:UIColor, pageCount:Int = 0, aspectRatio:CGFloat = 0, runFromDate:Date? = nil, runTillDate:Date? = nil, coverThumbImage:URL? = nil, dealerId:String? = nil, dealerName:String? = nil) {
        self.uuid = id
        self.bgColor = bgColor
        self.pageCount = pageCount
        self.aspectRatio = aspectRatio
        self.runFromDate = runFromDate
        self.runTillDate = runTillDate
        self.coverThumbImage = coverThumbImage
        self.dealerId = dealerId
        self.dealerName = dealerName
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



