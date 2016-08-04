//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation

@objc(SGNGraphRequest)
public class GraphRequest : NSObject {
    
    // every time a request is constructed, it is given a unique identifier
    public let identifier: String = NSUUID().UUIDString
    
    public let query:String
    public let operationName:String
    public let variables:[String:AnyObject]?
    
    public init(query:String, operationName:String, variables:[String:AnyObject]? = nil) {
        self.query = query
        self.operationName = operationName
        self.variables = variables
    }
}


public extension GraphRequest {
    
    public func start(completion:GraphConnection.RequestCompletionHandler) {
        let conn = GraphConnection()
        conn.start(self, completion: completion)
    }
    
}
