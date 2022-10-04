///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import XCTest
import Foundation
@testable import TjekAPI

class OpeningHoursTests: XCTestCase {
    
    func testOpeningHoursDecodable() throws {
        let dayOfWeek = "monday"
        let opens = "09:00:00"
        let closes = "21:00:00"
        let validFrom = "2022-04-03T00:00:00+02:00"
        let validUntil = "2022-04-04T00:00:00+02:00"
        
        let v2df = DateFormatter()
        v2df.locale = Locale(identifier: "en_US_POSIX")
        v2df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let decoder = APIPath.v2.jsonDecoder
        
        let fromDate = v2df.date(from: validFrom)!
        let toDate = v2df.date(from: validUntil)!
        
//
// MARK: Test only dayOfWeek
//
        
        let minDayJson = """
{
        "day_of_week": "\(dayOfWeek)"
}
"""
        let result1: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: minDayJson.data(using: .utf8)!)
        let expectedResult1 = OpeningHours_v2(period: .dayOfWeek(.monday), opens: nil, closes: nil)
        
        XCTAssertEqual(result1, expectedResult1)

//
// MARK: Test dayOfWeek with hours
//
        
        let maxDayJson = """
{
    "day_of_week": "\(dayOfWeek)",
    "opens": "\(opens)",
    "closes": "\(closes)"
}
"""
        let result2: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: maxDayJson.data(using: .utf8)!)
        let expectedResult2 = OpeningHours_v2(period: .dayOfWeek(.monday), opens: .init(string: opens), closes: .init(string: closes))
        
        XCTAssertEqual(result2, expectedResult2)
        
//
// MARK: Test dateRange
//
        
        let minRangeJson = """
{
    "valid_from": "\(validFrom)",
    "valid_until": "\(validUntil)"
}
"""
        
        let result3: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: minRangeJson.data(using: .utf8)!)
        let expectedResult3 = OpeningHours_v2(period: .dateRange(fromDate ... toDate), opens: nil, closes: nil)
        
        XCTAssertEqual(result3, expectedResult3)
        
//
// MARK: Test dateRange with hours
//
        
        let maxRangeJson = """
{
        "valid_from": "\(validFrom)",
        "valid_until": "\(validUntil)",
        "opens": "\(opens)",
        "closes": "\(closes)"
}
"""
        
        let result4: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: maxRangeJson.data(using: .utf8)!)
        let expectedResult4 = OpeningHours_v2(period: .dateRange(fromDate ... toDate), opens: .init(string: opens), closes: .init(string: closes))
        
        XCTAssertEqual(result4, expectedResult4)
        
        let emptyJson = """
{}
"""
        let result5: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: emptyJson.data(using: .utf8)!)
        let expectedResult5 = OpeningHours_v2(period: .dateRange(.distantPast ... .distantPast), opens: nil, closes: nil)
        
        XCTAssertEqual(result5, expectedResult5)
        
        let corruptJson = """
{
    "day_of_week": "monday",
    "valid_from": "11-03-2022",
    "valid_until": "12-03-2022"
}
"""
        let result6: OpeningHours_v2 = try decoder.decode(OpeningHours_v2.self, from: corruptJson.data(using: .utf8)!)
        let expectedResult6 = OpeningHours_v2(period: .dayOfWeek(.monday), opens: nil, closes: nil)
        
        XCTAssertEqual(result6, expectedResult6)
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
        let mondayTestDate = v2df.date(from: "2022-03-14T14:00:00+0000")!
        
        let openingHours = OpeningHours_v2(period: .dateRange(startDate...endDate), opens: .init(string: opens), closes: .init(string: closes))
        let mondayHours = OpeningHours_v2(period: .dayOfWeek(.monday), opens: .init(string: opens), closes: .init(string: closes))
        
        XCTAssertTrue(openingHours.contains(date: testDate))
        XCTAssertTrue(mondayHours.contains(date: mondayTestDate))
        XCTAssertFalse(mondayHours.contains(date: testDate))
        XCTAssertFalse(openingHours.contains(date: Date()))
    }
}
