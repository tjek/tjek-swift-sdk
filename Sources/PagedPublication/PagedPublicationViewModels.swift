//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


/// This protocol defines all the properties needed to render the background of the publication.
@objc (SGNPagedPublicationViewModelProtocol)
public protocol PagedPublicationViewModelProtocol {
    
    /// The identifier of the publication
    var publicationId:String { get }
    
    /// The identifier of the provider of the publication
    var ownerId:String { get }
    
    /// the background brand color of the publication
    var bgColor:UIColor { get }
    
    /// expected total number of pages. Should be ≤0 if unknown.
    var pageCount:Int { get }
    
    /// width/height ratio of pages in this publication. Should be ≤0 if unknown.
    var aspectRatio:CGFloat { get }
    
}


/// A concrete instance of the PagedPublicationViewModel protocol
@objc (SGNPagedPublicationViewModel)
open class PagedPublicationViewModel : NSObject, PagedPublicationViewModelProtocol {
    
    public var publicationId:String
    public var ownerId:String
    public var bgColor:UIColor
    public var pageCount:Int
    public var aspectRatio:CGFloat = 0
    
    public init(publicationId:String, ownerId:String, bgColor:UIColor, pageCount:Int, aspectRatio:CGFloat) {
        self.publicationId = publicationId
        self.ownerId = ownerId
        self.bgColor = bgColor
        self.pageCount = pageCount
        self.aspectRatio = aspectRatio
    }
}




/// This protocol defines all the properties we need to show a hotspot
@objc (SGNPagedPublicationHotspotViewModelProtocol)
public protocol PagedPublicationHotspotViewModelProtocol : class {
    
    /// return CGRectNull if the hotspot isnt in that page
    func getLocationForPageIndex(_ pageIndex:Int) -> CGRect
    
    func getPageIndexes() -> IndexSet
}

/// This concrete implementation of a hotspot contains no data, so is designed for subclassing.
@objc(SGNPagedPublicationEmptyHotspotViewModel)
open class PagedPublicationEmptyHotspotViewModel : NSObject, PagedPublicationHotspotViewModelProtocol {
    
    fileprivate var pageLocations:[Int:CGRect]
    
    open func getLocationForPageIndex(_ pageIndex:Int) -> CGRect {
        return pageLocations[pageIndex] ?? CGRect.null
    }
    open func getPageIndexes() -> IndexSet {
        let pageIndexes = NSMutableIndexSet()
        for (pageIndex, _) in pageLocations {
            pageIndexes.add(pageIndex)
        }
        return pageIndexes as IndexSet
    }
    
    public init(pageLocations:[Int:CGRect]) {
        self.pageLocations = pageLocations
    }
}






@objc (SGNPagedPublicationPageViewModelProtocol)
public protocol PagedPublicationPageViewModelProtocol {
    
    var pageIndex:Int { get }
    
    var pageTitle:String? { get }
    
    var aspectRatio:CGFloat { get }
    
    var viewImageURL:URL? { get }
    
    var zoomImageURL:URL? { get }
}



@objc (SGNPagedPublicationPageViewModel)
open class PagedPublicationPageViewModel : NSObject, PagedPublicationPageViewModelProtocol {
    
    public var pageIndex: Int
    
    public var aspectRatio: CGFloat = 0
    
    public var pageTitle: String?
    
    public var viewImageURL:URL?
    
    public var zoomImageURL:URL?
    
    
    public init(pageIndex:Int, pageTitle:String?, aspectRatio:CGFloat = 0, viewImageURL:URL? = nil, zoomImageURL:URL? = nil) {
        self.pageIndex = pageIndex
        self.pageTitle = pageTitle
        self.aspectRatio = aspectRatio
        self.viewImageURL = viewImageURL
        self.zoomImageURL = zoomImageURL
    }
}

