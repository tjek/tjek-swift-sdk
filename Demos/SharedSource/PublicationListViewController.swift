//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import ShopGunSDK
import Incito
import CoreLocation

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
        
        self.title = "ShopGunSDK Demo"
        
        // Show the loading spinner
        self.contentVC = LoadingViewController()
        
        // Build the request we wish to send to the coreAPI
        let location = CoreAPI.Requests.LocationQuery(coordinate: CLLocationCoordinate2D(latitude:55.631090, longitude: 12.577236), radius: nil)
        let publicationReq = CoreAPI.Requests.getPublications(near: location, sortedBy: .newestPublished)
        
        // Perform the request
        CoreAPI.shared.request(publicationReq) { [weak self] result in
            
            // Show different contents depending upon the result of the request
            switch result {
            case let .success(publications):
                self?.contentVC = PublicationListContentsViewController(
                    publications: publications,
                    shouldOpenIncito: { [weak self] in self?.openIncito(for: $0) },
                    shouldOpenPagedPub: { [weak self] in self?.openPagedPub(for: $0) }
                )
            case let .failure(error):
                self?.contentVC = ErrorViewController(error: error)
            }
        }
    }
    
    func openIncito(for publication: CoreAPI.PagedPublication) {
        
        // Create an instance of `IncitoLoaderViewController`
        let incitoVC = DemoIncitoViewController()
        
        incitoVC.load(publication: publication)

        self.navigationController?.pushViewController(incitoVC, animated: true)
    }
    
    func openPagedPub(for publication: CoreAPI.PagedPublication) {
        
        // Create a view controller containing a `PagedPublicationView`
        let pagedPubVC = DemoPagedPublicationViewController()
       
        pagedPubVC.load(publication: publication)
       
        self.navigationController?.pushViewController(pagedPubVC, animated: true)
    }
}
