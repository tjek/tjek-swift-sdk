import PlaygroundSupport
import UIKit
import ShopGunSDK // NOTE: you must build this targetting an iOS simulator

class ExampleOutroView: PagedPublicationView.OutroView {
    func configure() {
        print("config outro")
        backgroundColor = .orange
    }
}

class ExampleViewController: UIViewController, PagedPublicationViewDataSource {
    
    lazy var publicationView: PagedPublicationView = {
        let view = PagedPublicationView()
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        publicationView.frame = view.frame
        publicationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(publicationView)
        publicationView.dataSource = self
        publicationView.reload(publicationId: "9e42Nlz",
                               initialPageIndex: 43)
        
        publicationView.didEnterForeground()
    }
    
    func outroViewProperties(for pagedPublicationView: PagedPublicationView) -> PagedPublicationView.OutroViewProperties? {
        return (viewClass: ExampleOutroView.self, width: 0.9, maxZoom: 1.0)
    }
    func configure(outroView: PagedPublicationView.OutroView, for pagedPublicationView: PagedPublicationView) {
        (outroView as? ExampleOutroView)?.configure()
    }
    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String? {
        return "Page \((pageIndexes.first ?? 0) + 1) of \(pageCount)"
    }
    func errorView(with error: Error?, for pagedPublicationView: PagedPublicationView) -> UIView? {
        return nil
    }
}

PlaygroundPage.current.needsIndefiniteExecution = true

ShopGunSDK.configureForPlaygroundDevelopment()

let vc = ExampleViewController()

PlaygroundPage.current.liveView = vc
