import UIKit

import ShopGunSDK // NOTE: you must build this targetting an iOS simulator

class ExampleViewController: UIViewController {
    
    lazy var publicationView: PagedPublicationView = {
        let view = PagedPublicationView()
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        publicationView.frame = view.frame
        publicationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(publicationView)
        
        publicationView.update(publicationId: "abc123",
                               pageIndex: 0,
                               initialProperties: .init(bgColor: .blue, pageCount: 10, aspectRatio: 1.6))
    }
}

let vc = ExampleViewController()
vc.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)

import PlaygroundSupport

PlaygroundPage.current.liveView = vc
