///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation

public struct ImageURL: Equatable, Codable, Hashable {
    public var url: URL
    public var width: Int
    
    public init(url: URL, width: Int) {
        self.url = url
        self.width = width
    }
}

extension Collection where Element == ImageURL {
    
    public var smallestToLargest: [ImageURL] {
        self.sorted(by: { $0.width <= $1.width })
    }
    
    public var largestImage: ImageURL? {
        smallestToLargest.last
    }
    
    public var smallestImage: ImageURL? {
        smallestToLargest.first
    }
    
    // TODO: Add ability to 'round up' to nearest image: LH - 25 May 2020
    
    /**
     Returns the smallest image that is at least as wide as the specified `minWidth`.
     
     If no imageURLs match the criteria (they are all smaller than the specified minWidth), and `fallbackToNearest` is true, this will return the largest possible image.
     */
    public func imageURL(widthAtLeast minWidth: Int, fallbackToNearest: Bool) -> ImageURL? {
        let urls = smallestToLargest
        return urls.first(where: { $0.width >= minWidth }) ?? (fallbackToNearest ? urls.last : nil)
    }
    
    /**
     Returns the largest imageURL whose width is no more than the specified `maxWidth`.
     
     If no imageURLs match the criteria (they are all bigger than the specified maxWidth), and `fallbackToNearest` is true, this will return the smallest possible image.
     */
    public func imageURL(widthNoMoreThan maxWidth: Int, fallbackToNearest: Bool) -> ImageURL? {
        let urls = smallestToLargest
        return urls.last(where: { $0.width <= maxWidth }) ?? (fallbackToNearest ? urls.first : nil)
    }
}
