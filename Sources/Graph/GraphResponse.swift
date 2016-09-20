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
open class GraphResponse : NSObject {
    fileprivate let responseObject: AnyObject?
    
    // responseObject is the post-parsing data out of the server.
    // eg. Dictionary/Array
    public init(responseObject: AnyObject?) {
        self.responseObject = responseObject
    }

    
    open var dictionaryValue: [String : AnyObject]? {
        return responseObject as? [String : AnyObject]
    }
    
    open var arrayValue: [AnyObject]? {
        return responseObject as? [AnyObject]
    }
    
    open var stringValue: String? {
        return responseObject as? String
    }
}
