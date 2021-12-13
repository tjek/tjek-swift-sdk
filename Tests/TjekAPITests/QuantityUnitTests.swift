///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import XCTest
import Foundation
@testable import TjekAPI

class QuantityUnitTests: XCTestCase {

    func testUnits() {

        // long ton conversion is correct
        let longTonInKg = (QuantityUnit.imperialTon.unit as? UnitMass)?.converter.baseUnitValue(fromValue: 1)
        XCTAssertEqual(longTonInKg, 1016.0469)
        
        // only pieces dont have units
        XCTAssertEqual(
            QuantityUnit.allCases.filter({ $0.unit == nil }),
            [QuantityUnit.piece]
        )
    }
    
    func testConversionFactor() {
        XCTAssertEqual(QuantityUnit.gram.conversionFactor(to: .kilogram), 0.001)
        XCTAssertEqual(QuantityUnit.kilogram.conversionFactor(to: .gram), 1000.0)
        XCTAssertEqual(QuantityUnit.pound.conversionFactor(to: .gram), 453.592)
    }
}
