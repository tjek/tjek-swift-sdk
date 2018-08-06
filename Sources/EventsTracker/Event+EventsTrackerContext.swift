//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension Event {
    
    func addingContext(_ context: EventsTracker.Context) -> Event {
        
        var event = self
        
        // add the CountryCode (if available)
        if let countryCode = context.countryCode {
            event = event.addingCountryCode(countryCode)
        }
        
        // add geohash
        // TODO ...
        //        event = event.addingLocation(geohash: "abc", timestamp: Date())
        
        return event
    }
}
