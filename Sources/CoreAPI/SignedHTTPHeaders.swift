//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import Foundation
import CommonCrypto

internal func signedHTTPHeaders(for auth:(token: String, secret: String)) -> [String: String] {
    // make an SHA256 Hex string
    let hashString: String?
    if let data = (auth.secret + auth.token).data(using: .utf8) {
        hashString = data.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> String in
            var hash: [UInt8] = .init(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            _ = CC_SHA256(bytes, CC_LONG(data.count), &hash)
            
            return hash.reduce("", { $0 + String(format: "%02x", $1) })
        })
    } else {
        hashString = nil
    }
    
    var headers: [String: String] = [:]
    
    headers["X-Token"] = auth.token
    headers["X-Signature"] = hashString
    
    return headers
}
