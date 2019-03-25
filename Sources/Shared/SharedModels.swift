//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation

/// The type of a IncitoPublication's unique identifier in the Graph
public enum IncitoGraphType {}
public typealias IncitoGraphIdentifier = GenericIdentifier<IncitoGraphType>

/// The type of a PagedPublication's unique identifier.
public enum PagedPublicationCoreAPIType {}
public typealias PagedPublicationCoreAPIIdentifier = GenericIdentifier<PagedPublicationCoreAPIType>
