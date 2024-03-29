///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import UIKit
import Verso

extension PagedPublicationView {
    
    /// The view containing the pages and the page number label
    /// This will fill the entirety of the publicationView, but will use layoutMargins for pageLabel alignment
    class ContentsView: UIView {
        
        struct Properties {
            var pageLabelString: String?
            var isBackgroundBlack: Bool = false
            var showAdditionalLoading: Bool = false
        }

        var properties = Properties()
        
        func update(properties: Properties) {
            self.properties = properties
            pageNumberLabel.isHidden = shouldHidePageCountLabel
            updatePageNumberLabel(with: properties.pageLabelString)
            
            var spinnerFrame = additionalLoadingSpinner.frame
            spinnerFrame.origin.x = self.layoutMarginsGuide.layoutFrame.maxX - spinnerFrame.width
            spinnerFrame.origin.y = pageNumberLabel.frame.midY - (spinnerFrame.height / 2)
            additionalLoadingSpinner.frame = spinnerFrame
            
            additionalLoadingSpinner.color = properties.isBackgroundBlack ? .white : UIColor(white: 0, alpha: 0.7)
            additionalLoadingSpinner.alpha = properties.showAdditionalLoading ? 1 : 0
        }
        
        // MARK: Views
        
        var versoView = VersoView()
        fileprivate var pageNumberLabel = PageNumberLabel()
        var shouldHidePageCountLabel: Bool = false
        
        var additionalLoadingSpinner: UIActivityIndicatorView = {
            let view = UIActivityIndicatorView(style: .white)
            view.hidesWhenStopped = false
            view.startAnimating()
            return view
        }()

        // MARK: UIView Lifecycle
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            versoView.frame = frame
            addSubview(versoView)
            addSubview(pageNumberLabel)
            addSubview(additionalLoadingSpinner)
            
            // initial state is invisible
            pageNumberLabel.alpha = 0
            additionalLoadingSpinner.alpha = 0
            
            setNeedsLayout()
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            versoView.frame = bounds
            self.update(properties: self.properties)
        }
    }
}

// MARK: -

private typealias ContentsPageNumberLabel = PagedPublicationView.ContentsView
extension ContentsPageNumberLabel {
    
    fileprivate func updatePageNumberLabel(with text: String?) {
        if let pageLabelString = text {
            // update the text & show label
            if pageNumberLabel.text != pageLabelString && self.pageNumberLabel.text != nil && self.pageNumberLabel.alpha != 0 {
                UIView.transition(with: pageNumberLabel, duration: 0.15, options: [.transitionCrossDissolve, .beginFromCurrentState], animations: {
                    self.pageNumberLabel.text = text
                    self.layoutPageNumberLabel()
                })
            } else {
                pageNumberLabel.text = text
                self.layoutPageNumberLabel()
            }
            
            showPageNumberLabel()
        } else {
            // hide the label
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dimPageNumberLabel), object: nil)
            UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
                self.pageNumberLabel.alpha = 0
            })
        }
    }
    
    fileprivate func layoutPageNumberLabel() {
        // layout page number label
        var lblFrame = pageNumberLabel.frame
        lblFrame.size = pageNumberLabel.sizeThatFits(bounds.size)
        
        lblFrame.size.width =  ceil(lblFrame.size.width)
        lblFrame.size.height = round(lblFrame.size.height)
        
        lblFrame.origin.x = round(bounds.midX - (lblFrame.width / 2))
        
        // change the bottom offset of the pageLabel when on iPhoneX
        let pageLabelBottomOffset: CGFloat
        if #available(iOS 11.0, *),
            UIDevice.current.userInterfaceIdiom == .phone,
            UIScreen.main.nativeBounds.height == 2436 { // iPhoneX
            // position above the home indicator on iPhoneX
            pageLabelBottomOffset = bounds.maxY - safeAreaLayoutGuide.layoutFrame.maxY
        } else {
            pageLabelBottomOffset = 11
        }
        
        lblFrame.origin.y = round(bounds.maxY - pageLabelBottomOffset - lblFrame.height)
        
        pageNumberLabel.frame = lblFrame
    }
    
    @objc
    fileprivate func dimPageNumberLabel() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.beginFromCurrentState], animations: {
            self.pageNumberLabel.alpha = 0.2
        }, completion: nil)
    }
    
    fileprivate func showPageNumberLabel() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dimPageNumberLabel), object: nil)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState], animations: {
            self.pageNumberLabel.alpha = 1.0
        }, completion: nil)
        
        self.perform(#selector(dimPageNumberLabel), with: nil, afterDelay: 1.0)
    }
    
    fileprivate class PageNumberLabel: UILabel {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            layer.cornerRadius = 6
            layer.masksToBounds = true
            textColor = .white
            
            layer.backgroundColor = UIColor(white: 0, alpha: 0.3).cgColor
            textAlignment = .center
            
            //  monospaced numbers
            let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFont.TextStyle.headline)
            
            let features: [[UIFontDescriptor.FeatureKey: Any]] = [
                [.featureIdentifier: kNumberSpacingType,
                 .typeIdentifier: kMonospacedNumbersSelector],
                [.featureIdentifier: kStylisticAlternativesType,
                 .typeIdentifier: kStylisticAltOneOnSelector],
                [.featureIdentifier: kStylisticAlternativesType,
                 .typeIdentifier: kStylisticAltTwoOnSelector]
            ]
            
            let monospacedNumbersFontDescriptor = fontDescriptor.addingAttributes([.featureSettings: features])
            //TODO: dynamic font size
            font = UIFont(descriptor: monospacedNumbersFontDescriptor, size: 16)
            
            numberOfLines = 1
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var labelEdgeInsets: UIEdgeInsets = UIEdgeInsets(top: 4, left: 22, bottom: 4, right: 22)
        
        override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
            var rect = super.textRect(forBounds: bounds.inset(by: labelEdgeInsets), limitedToNumberOfLines: numberOfLines)
            
            rect.origin.x -= labelEdgeInsets.left
            rect.origin.y -= labelEdgeInsets.top
            rect.size.width += labelEdgeInsets.left + labelEdgeInsets.right
            rect.size.height += labelEdgeInsets.top + labelEdgeInsets.bottom
            
            return rect
        }
        override func drawText(in rect: CGRect) {
            super.drawText(in: rect.inset(by: labelEdgeInsets))
        }
    }
}
