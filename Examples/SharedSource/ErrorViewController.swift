///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import UIKit

class ErrorViewController: UIViewController {
    let error: Error
    
    init(error: Error) {
        self.error = error
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = .white
        
        let errorLabel = UILabel()
        errorLabel.text = "😭 \(error.localizedDescription)\n\n\(error)"
        errorLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.textColor = .red
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(errorLabel)
        
        NSLayoutConstraint.activate([
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
            ])
    }
}
