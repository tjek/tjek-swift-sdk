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
    
    /**
     These are the set of reserved event types that the knows how to handle.
     */
    public enum EventType: Int {
        case dummy                          = 0
        case pagedPublicationOpened         = 1
        case pagedPublicationPageOpened     = 2
        case offerOpened                    = 3
        case clientSessionOpened            = 4
        case searched                       = 5
        case offerOpenedAfterSearch         = 7
    }
    
    /**
     The dummy event used for testing purposes.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     */
    internal static func dummy(timestamp: Date = Date()) -> Event {
        return Event(timestamp: timestamp,
                     type: EventType.dummy.rawValue)
    }
    
    /**
     The event when a paged publication has been "opened" by a user. In general, "opening" a paged publication means any action that results in the paged publication being presented for browsing, which would also result in a paged publication page event.
     - parameter publicationId: The uuid of the publication.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func pagedPublicationOpened(
        _ publicationId: CoreAPI.PagedPublication.Identifier,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = EventsTracker.shared.viewTokenizer.tokenize
        ) -> Event {
        
        let payload: PayloadType = ["pp.id": .string(publicationId.rawValue)]
        
        return Event(timestamp: timestamp,
                     type: EventType.pagedPublicationOpened.rawValue,
                     payload: payload)
            .addingViewToken(content: publicationId.rawValue, tokenizer: tokenizer)
    }
    
    /**
     The event when a paged publication page has been "presented" to the user. "presented" in this context means any action that results in the paged publication page being drawn to the screen.
     - parameter publicationId: The uuid of the publication.
     - parameter pageNumber: The (1-indexed) number of the opened page.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func pagedPublicationPageOpened(
        _ publicationId: CoreAPI.PagedPublication.Identifier,
        pageNumber: Int,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = EventsTracker.shared.viewTokenizer.tokenize
        ) -> Event {
        
        let payload: PayloadType = ["pp.id": .string(publicationId.rawValue),
                                    "ppp.n": .int(pageNumber)]
        
        let viewTokenContent: String = {
            var intAddr = UInt32(pageNumber).bigEndian
            let intData = Data(buffer: UnsafeBufferPointer(start: &intAddr, count: 1))
            return publicationId.rawValue + (String(data: intData, encoding: .utf8) ?? "")
        }()
        
        return Event(timestamp: timestamp,
                     type: EventType.pagedPublicationPageOpened.rawValue,
                     payload: payload)
            .addingViewToken(content: viewTokenContent, tokenizer: tokenizer)
    }
    
    /**
     The event when an offer has been "presented" to the user. "presented" in this context means any action that results in the offer information (often, but not necessarily the offer image) being drawn to the screen.
     - parameter offerId: The uuid of the offer.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func offerOpened(
        _ offerId: CoreAPI.Offer.Identifier,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = EventsTracker.shared.viewTokenizer.tokenize
        ) -> Event {
        
        let payload: PayloadType = ["of.id": .string(offerId.rawValue)]
        
        return Event(timestamp: timestamp,
                     type: EventType.offerOpened.rawValue,
                     payload: payload)
            .addingViewToken(content: offerId.rawValue, tokenizer: tokenizer)
    }
    
    /**
     The event when the application is brought to the foreground. For phone apps this is every time the app is opened/resumed.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     */
    internal static func clientSessionOpened(timestamp: Date = Date()) -> Event {
        return Event(timestamp: timestamp,
                     type: EventType.clientSessionOpened.rawValue)
    }
    
    /**
     The event when a search is performed against the system.
     - parameter query: The search query as entered by the user.
     - parameter languageCode: The language the user is searching with (2-character ISO-639-1 code, or nil if no language can be detected)
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func searched(
        for query: String,
        languageCode: String?,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = EventsTracker.shared.viewTokenizer.tokenize
        ) -> Event {
        
        var payload: PayloadType = ["sea.q": .string(query)]
        if let lang = languageCode {
            payload["sea.l"] = .string(lang)
        }
        
        return Event(timestamp: timestamp,
                     type: EventType.searched.rawValue,
                     payload: payload)
            .addingViewToken(content: query, tokenizer: tokenizer)
    }
    
    /**
     The event when a search is performed against the system, and that search leads to an offer being opened.
     - parameter offerId: The Id of the offer that was opened.
     - parameter query: The search query, as entered by the user, that lead to the offer being opened.
     - parameter languageCode: The language the user is searching with (2-character ISO-639-1 code, or nil if no language can be detected)
     - parameter timestamp: The date that the event occurred. Defaults to now.
     */
    internal static func offerOpenedAfterSearch(
        offerId: CoreAPI.Offer.Identifier,
        query: String,
        languageCode: String?,
        timestamp: Date = Date()
        ) -> Event {
        
        var payload: PayloadType = [
            "sea.q": .string(query),
            "of.id": .string(offerId.rawValue)
        ]
        
        if let lang = languageCode {
            payload["sea.l"] = .string(lang)
        }
        
        return Event(timestamp: timestamp,
                     type: EventType.offerOpenedAfterSearch.rawValue,
                     payload: payload)
    }
}

extension Event {
    
    public static func offerOpened(_ offerId: CoreAPI.Offer.Identifier) -> Event {
        return offerOpened(
            offerId,
            timestamp: Date()
        )
    }
    
    public static func searched(
        for query: String,
        languageCode: String?
        ) -> Event {
        return searched(for: query, languageCode: languageCode, timestamp: Date())
    }
    
    public static func offerOpenedAfterSearch(
        offerId: CoreAPI.Offer.Identifier,
        query: String,
        languageCode: String?
        ) -> Event {
        return offerOpenedAfterSearch(offerId: offerId, query: query, languageCode: languageCode, timestamp: Date())
    }
}
