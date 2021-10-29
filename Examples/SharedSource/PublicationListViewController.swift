///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import TjekAPI
import UIKit

class PublicationListViewController: UIViewController {
    
    var contentVC: UIViewController? = nil {
        didSet {
            self.cycleFromViewController(
                oldViewController: oldValue,
                toViewController: contentVC
            )
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "TjekSDK Demo"
        
        // Show the loading spinner
        self.contentVC = LoadingViewController()
        
        // Build & send the request. You need to have first called one of the `TjekAPI.initialize()` functions to use `TjekAPI.shared`.
        TjekAPI.shared.send(.getPublications(near: LocationQuery(coordinate: (55.67376305237014, 12.590854433873217), maxRadius: nil))) { [weak self] result in
            // Show different contents depending upon the result of the request
            switch result {
            case let .success(publications):
                self?.contentVC = PublicationListContentsViewController(
                    publications: publications.results,
                    shouldOpenIncito: { [weak self] in self?.openIncito(for: $0) },
                    shouldOpenPagedPub: { [weak self] in self?.openPagedPub(for: $0) }
                )
            case let .failure(error):
                self?.contentVC = ErrorViewController(error: error)
            }
        }
    }
    
    func openIncito(for publication: Publication_v2) {
        
        // Create an instance of `IncitoLoaderViewController`
//        let incitoVC = DemoIncitoViewController()
//
//        incitoVC.load(publication: publication)
//
//        self.navigationController?.pushViewController(incitoVC, animated: true)
    }
    
    func openPagedPub(for publication: Publication_v2) {
        
        // Create a view controller containing a `PagedPublicationView`
//        let pagedPubVC = DemoPagedPublicationViewController()
//
//        pagedPubVC.load(publication: publication)
//
//        self.navigationController?.pushViewController(pagedPubVC, animated: true)
    }
}
