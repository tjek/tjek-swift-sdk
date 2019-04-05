//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension Result where Success == Data, Failure: Error {
    /// For all Result<Data> instances, this returns a new Result whose .success value is decoded from the data.
    /// If the decode fails it becomes a .error result
    public func decodeJSON<R: Decodable>() -> Result<R, Error> {
        switch self {
        case .failure(let err):
            return .failure(err)
        case .success(let data):
            return .init(catching: {
                try JSONDecoder().decode(R.self, from: data)
            })
        }
    }
}
