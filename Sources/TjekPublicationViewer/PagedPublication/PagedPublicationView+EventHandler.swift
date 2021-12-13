///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

#if !COCOAPODS // Cocoapods merges these modules
import TjekAPI
import TjekEventsTracker
#endif
import UIKit

extension PagedPublicationView {
    
    struct EventsHandler {
        
        let eventsTracker: TjekEventsTracker
        let publicationId: PublicationId
        
        private var lastTrackedPageIndexes: IndexSet = IndexSet()
        
        func didOpenPublication() {
            eventsTracker.trackEvent(.pagedPublicationOpened(publicationId))
        }
        
        mutating func didOpenPublicationPages(_ pageIndexes: IndexSet) {
            guard UIApplication.shared.applicationState == .active else {
                return
            }
            let pageIndexesToTrack = pageIndexes.subtracting(lastTrackedPageIndexes)
            pageIndexesToTrack.forEach { pageIndex in
                eventsTracker.trackEvent(.pagedPublicationPageOpened(publicationId, pageNumber: pageIndex + 1))
            }
            
            lastTrackedPageIndexes = pageIndexes
        }
        
        init(eventsTracker: TjekEventsTracker, publicationId: PublicationId) {
            self.eventsTracker = eventsTracker
            self.publicationId = publicationId
        }
    }
}
