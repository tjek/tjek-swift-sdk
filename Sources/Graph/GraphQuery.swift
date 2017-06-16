//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation


public typealias JSONEncodable = Any
public typealias GraphDict = [String:JSONEncodable]



// MARK: Query
// The body of an individual query. A request string & some variables.
// Concrete structs should be made for each actual type, so that input variables can be statically-typed

public protocol GraphQuery {
    var requestString:String { get }
    
    /// the name of the operation in the requestString to be queried
    var operationName:String { get }
    
    var variables:GraphDict? { get }
}

extension GraphQuery {
    var variables:GraphDict? { return nil }
}




public func loadQueryFile(name:String, bundle:Bundle = Bundle.main) -> String? {
    guard let filePath = bundle.path(forResource:name, ofType:nil) else {
        return nil
    }
    
    guard let request = try? String(contentsOfFile: filePath) else {
        return nil
    }
    
    return request
}
