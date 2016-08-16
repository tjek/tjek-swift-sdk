//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


/// Class to be sub-classed to implement a concrete VersoPageCell

public class VersoPageCell<T:UIView> : UICollectionViewCell {
    typealias PageContentsViewType = T
    
    
    // TODO: add cell configure method to make this page contents view private
    // TODO: make immutable?
    var pageContentsView:PageContentsViewType? = nil
    func setPageContentsView(pageContentsView:PageContentsViewType?) {
        self.pageContentsView?.removeFromSuperview()
        
        self.pageContentsView = pageContentsView
        
        if self.pageContentsView != nil {
            contentView.addSubview(pageContentsView!)
        }
    }
    
    private func _versoPageCellCommonInit() {
        setPageContentsView(PageContentsViewType())
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _versoPageCellCommonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _versoPageCellCommonInit()
    }
    
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let b = contentView.bounds
        
        if let view = pageContentsView {
            var frame = view.frame
            
            frame.size = view.sizeThatFits(b.size)
            
            // TODO: make sure size is within bounds
            frame.origin.y = round(CGRectGetMidY(b) - frame.size.height/2)
            switch contentMode {
            case .Left:
                frame.origin.x = CGRectGetMinX(b)
            case .Right:
                frame.origin.x = CGRectGetMaxX(b) - frame.size.width
            default: //center
                frame.origin.x = round(CGRectGetMidX(b) - frame.size.width/2)
            }
        
            view.frame = frame
        }
    }
    
    
    override public func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes) {
        if let attrs = layoutAttributes as? VersoPageLayoutAttributes {
            
            var newContentMode = UIViewContentMode.Center
            
            switch attrs.contentsAlignment {
            case .Center:
                newContentMode = .Center
            case .Left:
                newContentMode = .Left
            case .Right:
                newContentMode = .Right
            }
            
            contentMode = newContentMode
        }
    }
}
