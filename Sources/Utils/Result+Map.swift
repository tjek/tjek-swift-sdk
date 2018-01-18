//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension Result {
    /// Take a result, and if it is was success try to map the value to a new value using the `transform`
    /// If the transform fails (throws) then the Result becomes an error, containing the transform failure
    func map<R>(_ transform: ((A) throws -> R)) -> Result<R> {
        switch self {
        case .error(let err):
            return .error(err)
        case .success(let origVal):
            do {
                let newVal = try transform(origVal)
                return .success(newVal)
            } catch let mappingError {
                return .error(mappingError)
            }
        }
    }
}

extension Result where A == Data {
    /// For all Result<Data> instances, this returns a new Result whose .success value is decoded from the data.
    /// If the decode fails it becomes a .error result
    func decodeJSON<R>() -> Result<R> where R: Decodable {
        return self.map({ try JSONDecoder().decode(R.self, from: $0) })
    }
}
