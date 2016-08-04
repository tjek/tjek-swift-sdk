//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation

@objc(SGNGraphResponse)
public class GraphResponse : NSObject {
    private let responseObject: AnyObject?
    
    // responseObject is the post-parsing data out of the server.
    // eg. Dictionary/Array
    public init(responseObject: AnyObject?) {
        self.responseObject = responseObject
    }

    
    public var dictionaryValue: [String : AnyObject]? {
        return responseObject as? [String : AnyObject]
    }
    
    public var arrayValue: [AnyObject]? {
        return responseObject as? [AnyObject]
    }
    
    public var stringValue: String? {
        return responseObject as? String
    }
}
