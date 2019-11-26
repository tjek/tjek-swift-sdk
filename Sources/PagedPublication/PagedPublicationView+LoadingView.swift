//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension PagedPublicationView {

    class LoadingView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(spinner)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                spinner.leadingAnchor.constraint(equalTo: leadingAnchor),
                spinner.trailingAnchor.constraint(equalTo: trailingAnchor),
                spinner.topAnchor.constraint(equalTo: topAnchor),
                spinner.bottomAnchor.constraint(equalTo: bottomAnchor)
                ])
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        fileprivate lazy var spinner: UIActivityIndicatorView = {
            let view = UIActivityIndicatorView(style: .whiteLarge)
            view.color = UIColor(white: 0, alpha: 0.7)
            view.hidesWhenStopped = false
            view.startAnimating()
            return view
        }()
    }
}
