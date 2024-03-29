///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

#if !COCOAPODS // Cocoapods merges these modules
import TjekUtils
#endif

/// The uniquely tag the PublicationId
public enum PublicationIdTag {}
public typealias PublicationId = GenericIdentifier<PublicationIdTag>

/// The uniquely tag the BusinessId
public enum BusinessIdTag {}
public typealias BusinessId = GenericIdentifier<BusinessIdTag>

/// The uniquely tag the StoreId
public enum StoreIdTag {}
public typealias StoreId = GenericIdentifier<StoreIdTag>

/// The uniquely tag the OfferId
public enum OfferIdTag {}
public typealias OfferId = GenericIdentifier<OfferIdTag>
