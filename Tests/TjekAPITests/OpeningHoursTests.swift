///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import XCTest
import Foundation
@testable import TjekAPI

class OpeningHoursTests: XCTestCase {
    
    func testOpeningHoursDecodable() throws {
        let dayOfWeek = "monday"
        let opens = "10:00:00"
        let closes = "18:00:00"
        let validFrom = "2022-03-09T09:00:00+0000"
        let validUntil = "2022-03-10T19:00:00+0000"
        
        let v2df = DateFormatter()
        v2df.locale = Locale(identifier: "en_US_POSIX")
        v2df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let decoder = TjekAPI(config: try .init(apiKey: "apiKey", apiSecret: "apiSecret")).v2.defaultDecoder
        
        let fromDate = v2df.date(from: validFrom)!
        let toDate = v2df.date(from: validUntil)!
        
        let expectedDateRange = OpeningHours_v2(period: .dateRange(fromDate...toDate), opens: .init(string: opens), closes: .init(string: closes))
        
        let expectedWeekday = OpeningHours_v2(period: .dayOfWeek(.monday), opens: .init(string: opens), closes: .init(string: closes))
        
        let expectedNoPeriod = OpeningHours_v2(period: .dateRange(.distantPast ... .distantFuture ), opens: .init(string: opens), closes: .init(string: closes))
        
        let maxJson = """
{
    "day_of_week": "\(dayOfWeek)",
    "opens": "\(opens)",
    "closes": "\(closes)",
    "valid_from": "\(validFrom)",
    "valid_until": "\(validUntil)"
}
"""
        let openingHours: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: maxJson.data(using: .utf8)!)
        
        XCTAssertEqual(openingHours, expectedDateRange)
        XCTAssertNotEqual(openingHours, expectedWeekday)
        XCTAssertNoThrow(try decoder.decode(OpeningHours_v2.self, from: maxJson.data(using: .utf8)!))
        
        let midJson = """
{
    "day_of_week": "\(dayOfWeek)",
    "opens": "\(opens)",
    "closes": "\(closes)"
}
"""
        let openingHours1: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: midJson.data(using: .utf8)!)
        
        XCTAssertNotEqual(openingHours1, expectedDateRange)
        XCTAssertEqual(openingHours1, expectedWeekday)
        XCTAssertNoThrow(try decoder.decode(OpeningHours_v2.self, from: midJson.data(using: .utf8)!))
        
        let minJson = """
{
    "opens": "\(opens)",
    "closes": "\(closes)"
}
"""
        
        let openingHours2: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: minJson.data(using: .utf8)!)
        
        XCTAssertEqual(openingHours2, expectedNoPeriod)
        XCTAssertNotEqual(openingHours2, expectedDateRange)
        
        let emptyJson = """
{}
"""
        XCTAssertThrowsError(try decoder.decode(OpeningHours_v2.self, from: emptyJson.data(using: .utf8)!))
        
        let corruptJson = """
{
    "day_of_week": "monday",
    "valid_from": "11-03-2022",
    "valid_until": "12-03-2022"
}
"""
        XCTAssertThrowsError(try decoder.decode(OpeningHours_v2.self, from: corruptJson.data(using: .utf8)!))
        
        
    }
    
    func testOpeningHoursContains() {
        let v2df = DateFormatter()
        v2df.locale = Locale(identifier: "en_US_POSIX")
        v2df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        let opens = "10:00:00"
        let closes = "18:00:00"
    
        let startDate = v2df.date(from: "2022-03-09T09:00:00+0000")!
        let endDate = v2df.date(from: "2022-03-10T19:00:00+0000")!
        let testDate = v2df.date(from: "2022-03-10T16:00:00+0000")!
        
        let openingHours = OpeningHours_v2(period: .dateRange(startDate...endDate), opens: .init(string: opens), closes: .init(string: closes))
        let mondayHours = OpeningHours_v2(period: .dayOfWeek(.monday), opens: .init(string: opens), closes: .init(string: closes))
        
        XCTAssertTrue(openingHours.contains(date: testDate))
        XCTAssertFalse(mondayHours.contains(date: testDate))
        XCTAssertFalse(openingHours.contains(date: Date()))
    }
}
