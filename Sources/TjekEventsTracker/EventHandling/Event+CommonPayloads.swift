///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

extension Event {
    
    fileprivate enum CommonPayloadKeys: String {
        case trackId                = "_a" // NOTE: trackId is a semi-special case. For shipping events it is required, but not for constructing events.
        case locationHash           = "l.h"
        case locationHashTimestamp  = "l.ht"
        case viewToken              = "vt"
    }
    
    func addingTrackId(_ trackId: TjekEventsTracker.Config.TrackId) -> Event {
        var event = self
        event.mergePayload([CommonPayloadKeys.trackId.rawValue: .string(trackId.rawValue)])
        return event
    }
    
    func addingLocation(geohash: String, timestamp: Date) -> Event {
        var event = self
        event.mergePayload([CommonPayloadKeys.locationHash.rawValue: .string(geohash),
                            CommonPayloadKeys.locationHashTimestamp.rawValue: .int(timestamp.eventTimestamp)])
        return event
    }
    
    func addingViewToken(content: String, key: String = CommonPayloadKeys.viewToken.rawValue, tokenizer: Tokenizer) -> Event {
        var event = self
        event.mergePayload([key: .string(tokenizer(content))])
        return event
    }
}
