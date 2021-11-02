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
    
    struct EventsHandler {
        
        let eventsTracker: EventsTracker
        let publicationId: PagedPublicationView.PublicationModel.Identifier
        
        private var lastTrackedPageIndexes: IndexSet = IndexSet()
        
        func didOpenPublication() {
            #warning("Dont map ids like this: LH - 1 Nov 2021")
            eventsTracker.trackEvent(.pagedPublicationOpened(.init(rawValue: publicationId.rawValue)))
        }
        
        mutating func didOpenPublicationPages(_ pageIndexes: IndexSet) {
            guard UIApplication.shared.applicationState == .active else {
                return
            }
            let pageIndexesToTrack = pageIndexes.subtracting(lastTrackedPageIndexes)
            pageIndexesToTrack.forEach { pageIndex in
                #warning("Dont map ids like this: LH - 1 Nov 2021")
                eventsTracker.trackEvent(.pagedPublicationPageOpened(.init(rawValue: publicationId.rawValue), pageNumber: pageIndex + 1))
            }
            
            lastTrackedPageIndexes = pageIndexes
        }
        
        init(eventsTracker: EventsTracker, publicationId: PagedPublicationView.PublicationModel.Identifier) {
            self.eventsTracker = eventsTracker
            self.publicationId = publicationId
        }
    }
}
