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
import Incito

class DemoIncitoViewController: IncitoLoaderViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
    }
    
    func load(publication: CoreAPI.Publication) {
        self.title = publication.branding.name
        
        // Note: we are setting the `backgroundColor` on the View Controller (rather than `incitoVC.view.backgroundColor`)
        // This allows for the loading/error views to dynamically adjust to the changing of this property
        self.backgroundColor = publication.branding.color ?? .white
        
        // Start the actual loading of the incito.
        // By providing the related publicationId we can more accurately measure incito-read analytics
        super.load(publication: publication)
    }
}


extension DemoIncitoViewController: IncitoLoaderViewControllerDelegate {
    
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController) {
        
        // get the first view at the point of tapping that is an offer.
        viewController.firstOffer(at: point) {
            guard let tappedOffer = $0 else {
                return
            }
            
            print("👉 Did Tap Offer:", tappedOffer)
            
            // scroll to that offer
            viewController.scrollToElement(withId: tappedOffer.id, animated: true)
        }
    }
    
    func incitoDocumentLoaded(document: IncitoDocument, in viewController: IncitoViewController) {
        print("✅ Did Load Incito")
        
        // register a long-press gesture with the loaded IncitoViewController.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        viewController.addGesture(longPress)
    }
    
    @objc private func didLongPress(_ longPress: UILongPressGestureRecognizer) {
        guard longPress.state == .began else { return }
        guard let incitoVC = self.incitoViewController else { return }
        
        // Handle long-press gestures.
        // Find where the gesture occurred in the loaded IncitoViewController,
        // then find the offer that is at that location
        let point = longPress.location(in: incitoVC.view)
        
        // get the first view at the point of tapping that is an offer.
        incitoVC.firstOffer(at: point) {
            guard let pressedOffer = $0 else {
                return
            }
            
            print("👉👉 Did LongPress Offer:", pressedOffer)
            
            // scroll to the long-pressed offer
            incitoVC.scrollToElement(withId: pressedOffer.id, animated: true)
        }
    }
}
