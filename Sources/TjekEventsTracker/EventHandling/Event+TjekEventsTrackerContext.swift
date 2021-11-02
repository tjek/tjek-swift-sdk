///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

extension Event {
    
    func addingContext(_ context: TjekEventsTracker.Context) -> Event {
        
        var event = self
        
        // add geohash & timestamp (if available)
        if let location = context.location {
            event = event.addingLocation(geohash: location.geohash, timestamp: location.timestamp)
        }
        
        return event
    }
}
