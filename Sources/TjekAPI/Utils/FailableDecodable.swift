///
///  Copyright (c) 2022 Tjek. All rights reserved.
///

import Foundation

/**
 https://stackoverflow.com/a/52070521/318834
 Use when decoding a collection where you dont care if one of the items fails to decode.
 
 ```
 let foo: [User] = (try c.decode([FailableDecodable<User>].self, forKey: .foo)).compactMap(\.value)
 ```
 */
struct FailableDecodable<T: Decodable>: Decodable {
    let result: Result<T, Error>
    
    init(from decoder: Decoder) throws {
        result = Result(catching: { try T(from: decoder) })
    }
    var value: T? {
        try? result.get()
    }
}

struct FailableDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        var elements = [Element]()
        if let count = container.count {
            elements.reserveCapacity(count)
        }
        
        while !container.isAtEnd {
            if let element = try container.decode(FailableDecodable<Element>.self).value {
                elements.append(element)
            }
        }
        
        self.elements = elements
    }
}
