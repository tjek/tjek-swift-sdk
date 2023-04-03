///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation
#if !COCOAPODS // Cocoapods merges these modules
import TjekAPI
#endif

extension Event {
    
    /**
     These are the set of reserved event types that the knows how to handle.
     */
    public enum EventType: Int {
        case dummy                          = 0
        case pagedPublicationOpened         = 1
        case pagedPublicationPageOpened     = 2
        case offerInteraction               = 3
        case searched                       = 5
        case firstOfferOpenedAfterSearch    = 6
        case offerOpenedAfterSearch         = 7
        @available(*, deprecated, renamed: "incitoPublicationOpened_v2")
        case incitoPublicationOpened        = 8
        case searchResultsViewed            = 9
        case incitoPublicationOpened_v2     = 11
        case basicAnalytics                 = 12
        case incitoPublicationSectionOpened = 13
    }
    
    /**
     The dummy event used for testing purposes.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     */
    internal static func _dummy(timestamp: Date = Date()) -> Event {
        return Event(timestamp: timestamp,
                     type: EventType.dummy.rawValue)
    }
    
    /**
     The event when a paged publication has been "opened" by a user. In general, "opening" a paged publication means any action that results in the paged publication being presented for browsing, which would also result in a paged publication page event.
     - parameter publicationId: The uuid of the publication.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func _pagedPublicationOpened(
        _ publicationId: PublicationId,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
    ) -> Event {
        
        let payload: PayloadType = ["pp.id": .string(publicationId.rawValue)]
        
        return Event(timestamp: timestamp,
                     type: EventType.pagedPublicationOpened.rawValue,
                     payload: payload)
            .addingViewToken(content: publicationId.rawValue, tokenizer: tokenizer)
    }
    
    /**
     The event to report basic analytics i.e. new sessions, views opened.
     - parameter category: Event category, e.g. session and screen.
     - parameter action: Event action, e.g. opened, clicked.
     - parameter appVersion: Version of the app.
     - parameter screenName: Name of the view currently being presented.
     - parameter label: Event label if you want to describe it.
     - parameter value: An optional Int for recording metrics. Is not included in the tokenizer
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func _basicAnalytics(
        _ category: String,
        action: String,
        appVersion: String,
        screenName: String?,
        previousScreenName: String?,
        label: String?,
        value: Int?,
        flags: [String],
        deviceInfo: DeviceInfo,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
    ) -> Event {
        
        var payload: PayloadType = [
            "_av": .string(appVersion),
            "c": .string(category),
            "a": .string(action),
            "os": .string(deviceInfo.systemName),
            "osv": .string(deviceInfo.systemVersion)
        ]
        
        if let id = deviceInfo.hardwareId {
            payload["d"] = .string(id)
        }
        
        if let name = screenName {
            payload["s"] = .string(name)
        }
        
        if let previousName = previousScreenName {
            payload["ps"] = .string(previousName)
        }
        
        if let lbl = label {
            payload["l"] = .string(lbl)
        }
        
        if let val = value {
            payload["v"] = .int(val)
        }
        
        if !flags.isEmpty {
            payload["f"] = .array(flags.map({ .string($0) }))
        }
        
        let viewTokenContent: String = [category, action, screenName]
            .compactMap { $0 }
            .joined(separator: ".")
        
        return Event(timestamp: timestamp,
                     type: EventType.basicAnalytics.rawValue,
                     payload: payload)
            .addingViewToken(content: viewTokenContent, tokenizer: tokenizer)
    }
    
    /**
     The event when a paged publication page has been "presented" to the user. "presented" in this context means any action that results in the paged publication page being drawn to the screen.
     - parameter publicationId: The uuid of the publication.
     - parameter pageNumber: The (1-indexed) number of the opened page.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func _pagedPublicationPageOpened(
        _ publicationId: PublicationId,
        pageNumber: Int,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
    ) -> Event {
        
        let payload: PayloadType = ["pp.id": .string(publicationId.rawValue),
                                    "ppp.n": .int(pageNumber)]
        
        let viewTokenContent: String = {
            let pageInt = UInt32(pageNumber).bigEndian
            
            let intData = withUnsafePointer(to: pageInt) { intAddr in
                Data(buffer: UnsafeBufferPointer(start: intAddr, count: 1))
            }
            
            return publicationId.rawValue + (String(data: intData, encoding: .utf8) ?? "")
        }()
        
        return Event(timestamp: timestamp,
                     type: EventType.pagedPublicationPageOpened.rawValue,
                     payload: payload)
            .addingViewToken(content: viewTokenContent, tokenizer: tokenizer)
    }
    
    /**
     The event when an offer has been interacted with by the user.
     - parameter offerId: The uuid of the offer.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter action: The type of interaction with the offer
     - parameter screenName: The name of the screen where actio has been taken
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func _offerInteraction(
        _ offerId: OfferId,
        timestamp: Date = Date(),
        action: String?,
        screenName: String?,
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
    ) -> Event {
        
        var payload: PayloadType = ["of.id": .string(offerId.rawValue)]
        if let a = action {
            payload["a"] = .string(a)
        }
        
        if let s = screenName {
            payload["s"] = .string(s)
        }
        
        return Event(timestamp: timestamp,
                     type: EventType.offerInteraction.rawValue,
                     payload: payload)
            .addingViewToken(content: offerId.rawValue, tokenizer: tokenizer)
    }
    
    /**
     The event when a search is performed against the system.
     - parameter query: The search query as entered by the user.
     - parameter languageCode: The language the user is searching with (2-character ISO-639-1 code, or nil if no language can be detected)
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func _searched(
        for query: String,
        languageCode: String?,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
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
     The event when a search is performed against the system, and that search leads to an offer being opened. This is only triggered for the _first_ offer to be interacted with.
     - parameter offerId: The Id of the offer that was opened.
     - parameter precedingOfferIds: An ordered list of offer ids that were shown above the offer that was interacted with. Empty list if only one offer was retrieved and clicked. This includes results from pagination. Internally, this list is prefixed (prefixed, not suffixed!) to 100 items.
     - parameter query: The search query, as entered by the user, that lead to the offer being opened.
     - parameter languageCode: The language the user is searching with (2-character ISO-639-1 code, or nil if no language can be detected)
     - parameter timestamp: The date that the event occurred. Defaults to now.
     */
    internal static func _firstOfferOpenedAfterSearch(
        offerId: OfferId,
        precedingOfferIds: [OfferId],
        query: String,
        languageCode: String?,
        timestamp: Date = Date()
    ) -> Event {
        
        var payload: PayloadType = [
            "sea.q": .string(query),
            "of.id": .string(offerId.rawValue),
            "of.ids": .array(precedingOfferIds
                                .prefix(100)
                                .map { .string($0.rawValue) })
        ]
        
        if let lang = languageCode {
            payload["sea.l"] = .string(lang)
        }
        
        return Event(timestamp: timestamp,
                     type: EventType.firstOfferOpenedAfterSearch.rawValue,
                     payload: payload)
    }
    
    /**
     The event when a search is performed against the system, and that search leads to an offer being opened.
     - parameter offerId: The Id of the offer that was opened.
     - parameter query: The search query, as entered by the user, that lead to the offer being opened.
     - parameter languageCode: The language the user is searching with (2-character ISO-639-1 code, or nil if no language can be detected)
     - parameter timestamp: The date that the event occurred. Defaults to now.
     */
    internal static func _offerOpenedAfterSearch(
        offerId: OfferId,
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
    
    /**
     The event when an incito publication has been "opened" by a user. In general, "opening" an incito publication means any action that results in the incito's contents being presented for browsing.
     - parameter incitoId: The uuid of the incito.
     - parameter pagedPublicationId: The (optional) uuid of the pagedPublication related to this incito, if known.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    @available(*, deprecated, renamed: "incitoPublicationOpened(_:timestamp:tokenizer:)")
    internal static func _incitoPublicationOpened(
        _ incitoId: PublicationId,
        pagedPublicationId: PublicationId?,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
    ) -> Event {
        
        let payload: PayloadType = ["ip.id": .string(incitoId.rawValue)]
        
        var event = Event(timestamp: timestamp,
                          type: EventType.incitoPublicationOpened.rawValue,
                          payload: payload)
            .addingViewToken(content: incitoId.rawValue, tokenizer: tokenizer)
        
        if let pagedPubId = pagedPublicationId {
            event = event.addingViewToken(content: pagedPubId.rawValue, key: "pp.vt", tokenizer: tokenizer)
        }
        
        return event
    }
    
    internal static func _incitoPublicationOpened(
        _ incitoPublicationId: PublicationId,
        timestamp: Date = Date(),
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
    ) -> Event {
        
        let payload: PayloadType = [
            "ip.id": .string(incitoPublicationId.rawValue)
        ]
        
        let event = Event(timestamp: timestamp,
                          type: EventType.incitoPublicationOpened_v2.rawValue,
                          payload: payload)
            .addingViewToken(content: incitoPublicationId.rawValue, tokenizer: tokenizer)
        
        return event
    }
    
    /**
     The event when a search is performed against the system, the user views the search results, and then the users leaves the search results screen.
     - parameter query: The search query, as entered by the user, that lead to the offer results being shown.
     - parameter languageCode: The language the user is searching with (2-character ISO-639-1 code, or nil if no language can be detected)
     - parameter resultsViewedCount: The total number of unique results seen by the user before they leave the screen. Cannot be < 1.
     - parameter timestamp: The date that the event occurred. Defaults to now.
     */
    internal static func _searchResultsViewed(
        query: String,
        languageCode: String?,
        resultsViewedCount: Int,
        timestamp: Date = Date()
    ) -> Event {
        
        var payload: PayloadType = [
            "sea.q": .string(query),
            "sea.v": .int(resultsViewedCount)
        ]
        
        if let lang = languageCode {
            payload["sea.l"] = .string(lang)
        }
        
        return Event(timestamp: timestamp,
                     type: EventType.searchResultsViewed.rawValue,
                     payload: payload)
    }
    
    /**
     The event when an incito section has disappeared from screen. Uniqueness is defined by the publicationId and the sectionPosition.
     - parameter publicationId: The uuid of the incito.
     - parameter sectionId: The id of the section that was opened (provided by the webview).
     - parameter sectionPosition: The position of the section that was opened (provided by the webview)
     - parameter openedAt: The date that the section appeared on screen.
     - parameter millisecsOnScreen: The number of milliseconds the section was on screen.
     - parameter tokenizer: A Tokenizer for generating the unique view token. Defaults to the shared EventsTrackers's viewTokenizer.
     */
    internal static func _incitoPublicationSectionOpened(
        _ publicationId: PublicationId,
        sectionId: String,
        sectionPosition: Int,
        openedAt: Date,
        millisecsOnScreen: Int,
        tokenizer: Tokenizer = TjekEventsTracker.shared.viewTokenizer.tokenize
    ) -> Event {
        
        let payload: PayloadType = [
            "ip.id": .string(publicationId.rawValue),
            "ips.id": .string(sectionId),
            "ips.p": .int(sectionPosition),
            "mos": .int(millisecsOnScreen)
        ]
        
        let viewTokenContent = "\(publicationId.rawValue).\(sectionId)"
        
        return Event(timestamp: openedAt,
                     type: EventType.incitoPublicationSectionOpened.rawValue,
                     payload: payload)
            .addingViewToken(content: viewTokenContent, tokenizer: tokenizer)
    }
}

extension Event {
    
    public static func offerInteraction(_ offerId: OfferId, action: String?, screenName: String?) -> Event {
        return _offerInteraction(
            offerId,
            timestamp: Date(),
            action: action,
            screenName: screenName
        )
    }
    
    public static func searched(
        for query: String,
        languageCode: String?
    ) -> Event {
        return _searched(for: query, languageCode: languageCode, timestamp: Date())
    }
    
    public static func basicAnalytics(
        category: String,
        action: String,
        appVersion: String,
        screenName: String?,
        previousScreenName: String?,
        label: String?,
        value: Int? = nil,
        flags: [String] = [],
        deviceInfo: DeviceInfo = .current
    ) -> Event {
        return _basicAnalytics(category, action: action, appVersion: appVersion, screenName: screenName, previousScreenName: previousScreenName, label: label, value: value, flags: flags, deviceInfo: deviceInfo, timestamp: Date())
    }
    
    public static func firstOfferOpenedAfterSearch(
        offerId: OfferId,
        precedingOfferIds: [OfferId],
        query: String,
        languageCode: String?
    ) -> Event {
        return _firstOfferOpenedAfterSearch(offerId: offerId, precedingOfferIds: precedingOfferIds, query: query, languageCode: languageCode, timestamp: Date())
    }
    public static func offerOpenedAfterSearch(
        offerId: OfferId,
        query: String,
        languageCode: String?
    ) -> Event {
        return _offerOpenedAfterSearch(offerId: offerId, query: query, languageCode: languageCode, timestamp: Date())
    }
    
    public static func pagedPublicationOpened(
        _ publicationId: PublicationId
    ) -> Event {
        return _pagedPublicationOpened(publicationId, timestamp: Date())
    }
    
    public static func pagedPublicationPageOpened(
        _ publicationId: PublicationId,
        pageNumber: Int,
        timestamp: Date = Date()
    ) -> Event {
        return _pagedPublicationPageOpened(publicationId, pageNumber: pageNumber, timestamp: timestamp)
    }
    
    @available(*, deprecated, renamed: "incitoPublicationOpened(_:)")
    public static func incitoPublicationOpened(
        _ incitoId: PublicationId,
        pagedPublicationId: PublicationId?
    ) -> Event {
        return _incitoPublicationOpened(
            incitoId,
            pagedPublicationId: pagedPublicationId,
            timestamp: Date()
        )
    }
    
    @available(*, deprecated, renamed: "incitoPublicationOpened(_:)")
    public static func incitoPublicationOpened(
        _ incitoPublicationId: PublicationId,
        isAlsoPagedPublication: Bool
    ) -> Event {
        return _incitoPublicationOpened(incitoPublicationId)
    }
    
    public static func incitoPublicationOpened(
        _ incitoPublicationId: PublicationId
    ) -> Event {
        return _incitoPublicationOpened(
            incitoPublicationId,
            timestamp: Date()
        )
    }
    
    public static func searchResultsViewed(
        query: String,
        languageCode: String?,
        resultsViewedCount: Int
    ) -> Event {
        return _searchResultsViewed(query: query, languageCode: languageCode, resultsViewedCount: resultsViewedCount, timestamp: Date())
    }
    
    public static func incitoPublicationSectionOpened(
        _ publicationId: PublicationId,
        sectionId: String,
        sectionPosition: Int,
        openedAt: Date,
        millisecsOnScreen: Int
    ) -> Event {
        return _incitoPublicationSectionOpened(publicationId, sectionId: sectionId, sectionPosition: sectionPosition, openedAt: openedAt, millisecsOnScreen: millisecsOnScreen)
    }
}
