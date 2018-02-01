import PlaygroundSupport
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
        
        publicationView.reload(publicationId: "9e42Nlz",
                               initialPageIndex: 20)
        
        publicationView.didEnterForeground()
    }
}

PlaygroundPage.current.needsIndefiniteExecution = true

ShopGunSDK.configureForPlaygroundDevelopment()

let vc = ExampleViewController()

PlaygroundPage.current.liveView = vc
