//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation
import Incito
import UIKit

extension IncitoViewController {
    
    public func firstOffer(at point: CGPoint, completion: @escaping (IncitoDocument.Element?) -> Void) {
        self.getFirstElement(at: point, where: { $0.role == "offer" }, completion: completion)
    }
}
