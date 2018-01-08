//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension Result where A == Data {
    func decodeJSON<R>() -> Result<R> where R: Decodable {
        switch self {
        case .error(let err):
            return .error(err)
        case .success(let data):
            do {
                return .success(try JSONDecoder().decode(R.self, from: data))
            } catch let decodingError {
                return .error(decodingError)
            }
        }
    }
}
