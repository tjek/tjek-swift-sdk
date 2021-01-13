//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import UIKit
import ShopGunSDK

class DemoPagedPublicationViewController: UIViewController {
    
    lazy var publicationView: PagedPublicationView = {
        let view = PagedPublicationView()
        return view
    }()
    
    override func loadView() {
        // set the publication view as the main view
        view = publicationView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // become datasource/delegate of the publicationView
        publicationView.dataSource = self
        publicationView.delegate = self
    }
    
    func load(publication: CoreAPI.Publication) {
        
        // If you havnt configured CoreAPI or EventsTracker (see `RootViewController.swift`), this is a simpler way of configuring both.
        // This, or the explicit CoreAPI configure method, MUST be called before the PagedPublication is reloaded.
        PagedPublicationView.configure(sendEvents: true)

        self.title = publication.branding.name
        self.view.backgroundColor = publication.branding.color ?? .white
        
        // Load the publication based on it's id
        // You can also provide a starting page index
        self.publicationView.reload(
            publicationId: publication.id,
            initialPageIndex: 0
        )
    }
}

extension DemoPagedPublicationViewController: PagedPublicationViewDataSource {
    
    func outroViewProperties(for pagedPublicationView: PagedPublicationView) -> PagedPublicationView.OutroViewProperties? {
        
        // If there is to be an outro shown, you can customize it here.
        return (viewClass: DemoPagedPubOutroView.self, width: 0.9, maxZoom: 1.0)
    }
    func configure(outroView: PagedPublicationView.OutroView, for pagedPublicationView: PagedPublicationView) {
        
        // When the outro is about to be shown, you should configure it now.
        (outroView as? DemoPagedPubOutroView)?.configure()
    }
}

extension DemoPagedPublicationViewController: PagedPublicationViewDelegate {
    
    func didTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {
        
        // listen for hotspot tap events
        print("👉 Did Tap Hotspots", hittingHotspots)
    }
}

// A simple example of an outro view
class DemoPagedPubOutroView: PagedPublicationView.OutroView {
    func configure() {
        self.backgroundColor = .orange
    }
}
