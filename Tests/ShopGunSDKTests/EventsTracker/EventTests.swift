//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import XCTest
@testable import ShopGunSDK

class EventTests: XCTestCase {

    func testInit() {

        // 1. given
        let id = Event.Identifier(rawValue: "abc123")
        let version = 4
        let type: Int = 999
        let date = Date()
        let payload: [String: JSONValue] = ["a": .string("abc"),
                                            "b": .int(1),
                                            "c": .number(1.5),
                                            "d": .array([.string("x"), .string("y"), .string("z")]),
                                            "e": .object(["m": .int(3)]),
                                            "f": .bool(true),
                                            "g": .null]
        
        // 2. when
        let defaultEvent = Event(type: type)
        let fullEvent = Event(id: id, version: version, timestamp: date, type: type, payload: payload)
        
        // 3. then
        XCTAssertEqual(defaultEvent.type, type)
        XCTAssertEqual(defaultEvent.version, 2)
        XCTAssertEqual(defaultEvent.payload, [:])
        XCTAssert(defaultEvent.timestamp >= date)
        XCTAssert(defaultEvent.timestamp <= Date())
        
        XCTAssertEqual(fullEvent.type, type)
        XCTAssertEqual(fullEvent.version, version)
        XCTAssertEqual(fullEvent.type, type)
        XCTAssertEqual(fullEvent.timestamp, date)
        XCTAssertEqual(fullEvent.payload, payload)
    }

    func testPayload() {
        // 1. given
        var baseEvent = Event(type: 999)
        
        // 2. when
        baseEvent.mergePayload(["a": .int(1),
                                "b": .string("foo")])
        
        baseEvent.mergePayload(["a": .int(2),
                                "b": .string("bar"),
                                "c": .bool(true)])
        // 3. then
        XCTAssertEqual(baseEvent.payload["a"], .int(2))
        XCTAssertEqual(baseEvent.payload["b"], .string("bar"))
        XCTAssertEqual(baseEvent.payload["c"], .bool(true))
    }
    
    func testEventTimestamp() {
        // 1. given
        let date1 = Date(timeIntervalSince1970: 123456)
        let date2 = Date(timeIntervalSince1970: -123456)
        let date3 = Date()
        let date4 = Date(eventTimestamp: 123456)
        
        // 3. then
        XCTAssertEqual(date1.eventTimestamp, 123456)
        XCTAssertEqual(date2.eventTimestamp, -123456)
        XCTAssertEqual(date3.eventTimestamp, Int(date3.timeIntervalSince1970))
        XCTAssertEqual(date4.eventTimestamp, 123456)
        XCTAssertEqual(date4, date1)
    }
    
    func testEventDecodable() {
        // 1. given
        let id = "abc"
        let version = 3
        let type = 2
        let timestamp = 123456
        let foo = "bar"
        let baz = 123
        
        let baseJson = """
{
    "_i": "\(id)",
    "_v": \(version),
    "_e": \(type),
    "_t": \(timestamp),
        "foo": "\(foo)",
        "baz": \(baz),
        "null": null,
        "arr": [1, 2, 3],
        "obj": {"a": 1, "b": 2, "c": 3}
}
"""
        let emptyJson = """
{}
"""
        let corruptTypeJson = """
{
    "_i": 123,
    "_v": "3",
    "_e": "1",
    "_t": false
}
"""
        // 2. when
        XCTAssertThrowsError(try JSONDecoder().decode(Event.self, from: emptyJson.data(using: .utf8)!))
        XCTAssertThrowsError(try JSONDecoder().decode(Event.self, from: corruptTypeJson.data(using: .utf8)!))
        XCTAssertNoThrow(try JSONDecoder().decode(Event.self, from: baseJson.data(using: .utf8)!))
        let baseEvent: Event = (try? JSONDecoder().decode(Event.self, from: baseJson.data(using: .utf8)!))!
        
        // 3. then
        XCTAssertEqual(baseEvent.id.rawValue, id)
        XCTAssertEqual(baseEvent.version, version)
        XCTAssertEqual(baseEvent.type, type)
        XCTAssertEqual(baseEvent.timestamp.eventTimestamp, timestamp)
        XCTAssertEqual(baseEvent.payload, ["foo": .string(foo),
                                           "baz": .int(baz),
                                           "null": .null,
                                           "arr": .array([.int(1), .int(2), .int(3)]),
                                           "obj": .object(["a": .int(1), "b": .int(2), "c": .int(3)])] as [String: JSONValue])
    }
    
    func testEventEncodable() {
        // 1. given
        let event = Event(id: Event.Identifier(rawValue: "abc123"), version: 3, timestamp: Date(), type: 123, payload: ["a": .string("foo"), "b": .int(123), "c": .bool(false), "d": .null])
        
        // 2. when
        
        XCTAssertNoThrow(try JSONEncoder().encode(event))
        
        let jsonData = (try? JSONEncoder().encode(event))!
        let decodedEvent = (try? JSONDecoder().decode(Event.self, from: jsonData))!
        
        // 3. then
        XCTAssertEqual(decodedEvent, event)
    }
}
