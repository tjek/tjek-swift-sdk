//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import Verso

extension PagedPublicationView {
    
    /// The view containing the pages, the page number label, and the progress bar
    /// This will fill the entirety of the publicationView, but will use layoutMargins for pageLabel alignment
    class ContentsView: UIView {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(progressBarView)
            addSubview(pageNumberLabel)
            
            // initial state is invisible
            progressBarView.alpha = 0
            pageNumberLabel.alpha = 0
            
            setNeedsLayout()
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        struct State {
            var progress: Double? // 0-1, nil if hidden
            var isBackgroundBlack: Bool //TODO: use visualEffect view instead?
            var pageNumberLabel: String?
            
            static var initial = State(progress: nil, isBackgroundBlack: false, pageNumberLabel: nil)
        }
        
        var state: State = .initial {
            didSet {
                setNeedsLayout()
            }
        }
        
        var progressBarHeight: CGFloat = 4 {
            didSet {
                if progressBarHeight != oldValue {
                    setNeedsLayout()
                }
            }
        }
        
        var pageLabelBottomOffset: CGFloat = 11 {
            didSet {
                if pageLabelBottomOffset != oldValue {
                    setNeedsLayout()
                }
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            updateProgressBar()
            updatePageNumberLabel()
        }
        
        
        // MARK: Progress Bar
        private var progressBarView = UIView()
        
        private func updateProgressBar() {
            
            // position the progressBar with the old width
            var frame = progressBarView.frame
            frame.origin.x = bounds.minX
            frame.origin.y = bounds.maxY - self.progressBarHeight
            frame.size.height = self.progressBarHeight
            progressBarView.frame = frame
            
            // update the background color
            self.progressBarView.backgroundColor = self.state.isBackgroundBlack ? UIColor(white: 0.58, alpha: 0.3) : UIColor(white: 0, alpha: 0.3)
            

            if let progress = self.state.progress {
                // resize & show the progress bar, dimming it after a delay

                // animate the change in width
                frame.size.width = round(bounds.width * min(max(CGFloat(progress), 0), 1))
                UIView.animate(withDuration: 0.3) {
                    self.progressBarView.frame = frame
                }
                
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dimProgressBarView), object: nil)
                
                UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState], animations: {
                    self.progressBarView.alpha = 1.0
                }, completion: nil)
                
                self.perform(#selector(dimProgressBarView), with: nil, afterDelay: 1.0)
            } else {
                // hide the progress bar
                UIView.animate(withDuration: 0.1) {
                    self.progressBarView.alpha = 0
                }
            }
        }
        
        @objc
        private func dimProgressBarView() {
            UIView.animate(withDuration: 1.0, delay: 0, options: [.beginFromCurrentState], animations: {
                self.progressBarView.alpha = 0.5
            }, completion: nil)
        }
        
        
        
        
        // MARK: Verso
        
        fileprivate var versoView = VersoView()
        
        // MARK: Page Number Label
        
        private var pageNumberLabel = PageNumberLabel()
        
        private func updatePageNumberLabel() {
            //            pageNumberLabel.text = self.state.pageNumberLabel
            //            layoutPageNumberLabel()
            //            showPageNumberLabel()
            //            return;
            
            if let text = self.state.pageNumberLabel {
                // update the text & show label
                if pageNumberLabel.text != text && self.pageNumberLabel.text != nil {
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
                }) { [weak self] (finished) in
                    if finished && self?.state.pageNumberLabel == nil {
                        self?.pageNumberLabel.text = nil
                    }
                }
            }
        }
        
        private func layoutPageNumberLabel() {
            // layout page number label
            var lblFrame = pageNumberLabel.frame
            lblFrame.size = pageNumberLabel.sizeThatFits(bounds.size)
            
            lblFrame.size.width =  ceil(lblFrame.size.width)
            lblFrame.size.height = round(lblFrame.size.height)
            
            lblFrame.origin.x = round(bounds.midX - (lblFrame.width / 2))
            lblFrame.origin.y = round(bounds.maxY - self.pageLabelBottomOffset - lblFrame.height)
            
            pageNumberLabel.frame = lblFrame
        }
        
        @objc
        private func dimPageNumberLabel() {
            UIView.animate(withDuration: 1.0, delay: 0, options: [.beginFromCurrentState], animations: {
                self.pageNumberLabel.alpha = 0.2
            }, completion: nil)
        }
        
        private func showPageNumberLabel() {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dimPageNumberLabel), object: nil)
            
            UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState], animations: {
                self.pageNumberLabel.alpha = 1.0
            }, completion: nil)
            
            self.perform(#selector(dimPageNumberLabel), with: nil, afterDelay: 1.0)
        }
        
        private class PageNumberLabel: UILabel {
            
            override init(frame: CGRect) {
                super.init(frame: frame)
                
                layer.cornerRadius = 6
                layer.masksToBounds = true
                textColor = .white
                
                layer.backgroundColor = UIColor(white: 0, alpha: 0.3).cgColor
                textAlignment = .center
                
                //  monospaced numbers
                let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle.headline)
                
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
                var rect = super.textRect(forBounds: UIEdgeInsetsInsetRect(bounds, labelEdgeInsets), limitedToNumberOfLines: numberOfLines)
                
                rect.origin.x -= labelEdgeInsets.left
                rect.origin.y -= labelEdgeInsets.top
                rect.size.width += labelEdgeInsets.left + labelEdgeInsets.right
                rect.size.height += labelEdgeInsets.top + labelEdgeInsets.bottom
                
                return rect
            }
            override func drawText(in rect: CGRect) {
                super.drawText(in: UIEdgeInsetsInsetRect(rect, labelEdgeInsets))
            }
        }
    }
}
