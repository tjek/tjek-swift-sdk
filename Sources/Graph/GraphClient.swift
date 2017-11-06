//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation


// MARK: - Graph Client

/// A protocol defining a server that handles any GraphRequests
public protocol GraphClient {
    @discardableResult func start(request:GraphRequestProtocol, completion:@escaping (Result<GraphResponse>) -> Void) -> Cancellable
}


/// When starting a request it returns an opaque object that must be cancellable.
public protocol Cancellable {
    func cancel()
}



/// A concrete implementation of the GraphClient protocol that has a connection to a NetworkTransport object, that does the requesting.
open class NetworkGraphClient : GraphClient {
    let connection:GraphNetworkTransport
    
    public init(connection:GraphNetworkTransport) {
        self.connection = connection
    }
    
    @discardableResult
    public func start(request:GraphRequestProtocol, completion:@escaping (Result<GraphResponse>) -> Void) -> Cancellable {        
        return connection.send(request: request, completion: completion)
    }
}


/// A convenience constructor that uses a concrete HTTP NetworkTransport connection
extension NetworkGraphClient {    
    public convenience init(url:URL) {
        self.init(connection:HTTPGraphNetworkTransport(url:url))
    }
}
