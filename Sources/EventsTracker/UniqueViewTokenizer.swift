//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

// TODO: UniqueViewTokenizer (save in EventsTracker?)
typealias Tokenizer = (String) -> String

struct UniqueViewTokenizer {
    let salt: String
    
    func tokenize(id: String) -> String {
        return id + salt
    }
    
    static var _shared: UniqueViewTokenizer?
    
    static var shared: UniqueViewTokenizer {
        
        // SIDE/CO-EFFECTS! caching/reloading/reseting from disk?
        if let vt = _shared {
            return vt
        } else {
            // TODO: decode/generate
            _shared = UniqueViewTokenizer(salt: "mySalt2")
            return _shared!
        }
    }
    
    static func resetSharedTokenizer() {
        _shared = nil
    }
}
