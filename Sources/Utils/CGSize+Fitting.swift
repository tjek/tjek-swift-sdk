//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension CGSize {
    
    /// The w/h aspect ratio of the size, or 1.0 if any of the dimensions are <= 0
    var aspectRatio: CGFloat {
        return width > 0 && height > 0 ? width / height : 1.0
    }
    
    /// Returns a size that is smaller than the current size, and but matches the specified w/h aspect ratio
    func scaledDownToAspectRatio(_ ratio: CGFloat) -> CGSize {
        var fittingSize = CGSize(width: self.height * ratio,
                                 height: self.width / ratio)
        if fittingSize.width <= self.width {
            fittingSize.height = self.height
        } else {
            fittingSize.width = self.width
        }
        return fittingSize
    }
    
    func closestFitting<T>(sizes: [(CGSize, T)], alwaysLargerIfPossible alwaysLarger: Bool) -> (size: CGSize, val: T)? {
        var closestOversized: (size: CGSize, diff: CGFloat, val: T)? = nil
        var closestUndersized: (size: CGSize, diff: CGFloat, val: T)? = nil
        
        for (inputSize, val) in sizes {
            // get the size the input would be that exactly fits into the target size.
            let fittingSize = self.scaledDownToAspectRatio(inputSize.aspectRatio)
            
            // how much difference between the actual input size, and how big it will be when fit to the target size
            // negative means input is smaller than the target size
            let fittingDiff = CGSize(width: inputSize.width - fittingSize.width,
                                     height: inputSize.height - fittingSize.height)
            
            // the largest (or smallest, if undersized) dimension of the fit size
            let maxDiff = max(abs(fittingDiff.width), abs(fittingDiff.height))
            
            if fittingDiff.width < 0 || fittingDiff.height < 0 {
                // the input is smaller than the fittingSize
                // the maxDiff is smaller than the last found undersized, so save it as the new closest
                if maxDiff < closestUndersized?.diff ?? CGFloat.infinity {
                    closestUndersized = (size: inputSize, diff: maxDiff, val: val)
                }
            } else {
                // the image is larger (or equal to) than the fittingSize
                // the maxDiff is smaller than the last found one oversized, so save it as the new closest
                if maxDiff < closestOversized?.diff ?? CGFloat.infinity {
                    closestOversized = (size: inputSize, diff: maxDiff, val: val)
                }
            }
        }
        
        // there is an oversized image, and the difference to the target size is less than the undersized image, so use it
        if let oversized = closestOversized, (alwaysLarger || oversized.diff < closestUndersized?.diff ?? CGFloat.infinity) {
            return (oversized.size, oversized.val)
        } else if let undersized = closestUndersized {
            return (undersized.size, undersized.val)
        } else {
            return nil
        }
    }
}
