///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import UIKit
import TjekUtils
import TjekAPI

extension Bundle {
    fileprivate static var ppResourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: PagedPublicationView.self)
        #endif
    }
}

extension PagedPublicationView {
    
    class ErrorView: UIView {
        
        enum ErrorType {
            case unknown
            case noContent
            case noInternet
            case serviceUnavailable
            case plannedMaintenance
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            iconImageView.setContentHuggingPriority(.required, for: .horizontal)
            iconImageView.setContentHuggingPriority(.required, for: .vertical)
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            messageLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            let stack = UIStackView(arrangedSubviews: [iconImageView, titleLabel, messageLabel, retryButton])
            stack.axis = .vertical
            stack.distribution = .fill
            stack.alignment = .center
            stack.spacing = 16
            
            addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: self.layoutMarginsGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: self.layoutMarginsGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: self.layoutMarginsGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: self.layoutMarginsGuide.bottomAnchor),
                
                stack.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
                ])
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func tintColorDidChange() {
            super.tintColorDidChange()
            
            iconImageView.tintColorDidChange()
            
            titleLabel.textColor = tintColor
            messageLabel.textColor = tintColor
            
            retryButton.setTitleColor(tintColor, for: .normal)
            retryButton.backgroundColor = tintColor.withAlphaComponent(0.05)
            retryButton.layer.borderColor = tintColor.cgColor
        }
        
        lazy var iconImageView = UIImageView()

        lazy var titleLabel: UILabel = {
            let lbl = UILabel()
            lbl.numberOfLines = 0
            lbl.font = UIFont.systemFont(ofSize: 24, weight: .regular)
            lbl.textAlignment = .center
            return lbl
        }()
        lazy var messageLabel: UILabel = {
            let lbl = UILabel()
            lbl.numberOfLines = 0
            lbl.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            lbl.textAlignment = .center
            lbl.alpha = 0.7
            return lbl
        }()
        lazy var retryButton: UIButton = {
            let btn = UIButton()
            btn.setTitle(PagedPublicationView.localizedString("errorView.retryButton.title"), for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular)
            btn.layer.borderWidth = 1
            btn.layer.cornerRadius = 8
            btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            return btn
        }()
        
        func update(for error: Error) {
            let errorType = error.errorViewType
            let title = errorType.title(forError: error)
            let message = errorType.message(forError: error)
            let isRetryable = errorType.isRetryable
            let iconImage = errorType.iconImage

            self.titleLabel.text = title
            self.messageLabel.text = message
            self.iconImageView.image = iconImage
            self.retryButton.isHidden = !isRetryable
        }
    }
}

extension PagedPublicationView {
    static func localizedString(_ key: String) -> String {
        return NSLocalizedString(key, tableName: "PagedPublicationView", bundle: .ppResourceBundle, comment: "")
    }
}
extension PagedPublicationView.ErrorView.ErrorType {
    func title(forError error: Error) -> String {
        switch self {
        case .noContent:
            return PagedPublicationView.localizedString("errorView.noContent.title")
        case .noInternet:
            return PagedPublicationView.localizedString("errorView.noInternet.title")
        case .serviceUnavailable, .unknown:
            return PagedPublicationView.localizedString("errorView.serviceUnavailable.title")
        case .plannedMaintenance:
            return PagedPublicationView.localizedString("errorView.plannedMaintenance.title")
        }
    }
    func message(forError error: Error) -> String {
        var msg: String
        switch self {
        case .noContent:
            msg = PagedPublicationView.localizedString("errorView.noContent.message")
        case .noInternet:
            msg = PagedPublicationView.localizedString("errorView.noInternet.message")
        case .serviceUnavailable, .unknown:
            msg = PagedPublicationView.localizedString("errorView.serviceUnavailable.message")
        case .plannedMaintenance:
            msg = PagedPublicationView.localizedString("errorView.plannedMaintenance.message")
        }

        #if DEBUG
            msg += "\n" + error.localizedDescription
        #endif
        return msg
    }
    
    var isRetryable: Bool {
        switch self {
        case .noContent:
            return false
        case .unknown,
             .noInternet,
             .serviceUnavailable,
             .plannedMaintenance:
            return true
        }
    }
    
    var iconImage: UIImage {
        let imgName: String
        switch self {
        case .unknown,
             .serviceUnavailable,
             .plannedMaintenance,
             .noInternet:
            
            imgName = "exclamation-icon"
        case .noContent:
            imgName = "nothing-found-icon"
        }
        
        return UIImage(named: imgName, in: .ppResourceBundle, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
    }
}

extension Error {
    var errorViewType: PagedPublicationView.ErrorView.ErrorType {
        
        if isNetworkError(self) {
            return .noInternet
        }
        
        if let knownError = (self as? APIError)?.serverResponse?.knownName {
            if knownError == .notFound || knownError == .catalogNotFound {
                return .noContent
            } else {
                return .serviceUnavailable
            }
        }
        
        return .unknown
    }
}
