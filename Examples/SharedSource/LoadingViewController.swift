///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import UIKit

class LoadingViewController: UIViewController {
    
    lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .whiteLarge)
        view.color = UIColor(white: 0, alpha: 0.7)
        return view
    }()
    
    override func loadView() {
        view = UIView()
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor)
            ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.activityIndicator.startAnimating()
        self.activityIndicator.alpha = 0
        UIView.animate(withDuration: 0.2, delay: 0.5, animations: {
            self.activityIndicator.alpha = 1
        })
    }
}
