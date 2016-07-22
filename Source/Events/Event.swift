//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation


struct Event {
    typealias VersionType = String
    
    /// This is the version of the events data.
    static let version:VersionType = "1.0.0"
    
    let type:String
    let uuid:String
    let trackId:String
    let recordedDate:NSDate
    
    
    var sentDate:NSDate?
    var context:[String:AnyObject] = [:]
    var properties:[String:AnyObject] = [:]
    
    
    /// If uuid is not specified one will be generated. If recordedDate is not specified current date will be used
    init(_ type:String, uuid:String = NSUUID().UUIDString, trackId:String, recordedDate:NSDate = NSDate()) {
        self.uuid = uuid
        self.type = type
        self.trackId = trackId
        self.recordedDate = recordedDate
    }
}


extension Event {
    func toDictionary() -> [String:AnyObject] {
        return [
            "version": Event.version,
        ]
    }
    static func fromDictionary(fromDict:[String:AnyObject]) -> Event? {
        return nil
    }
//
//    static func encode(event: Event) -> [String:]{
////        let personClassObject = HelperClass(person: person)
////        
////        NSKeyedArchiver.archiveRootObject(personClassObject, toFile: HelperClass.path())
//    }
//    
//    static func decode(path:NSURL) -> Event? {
////        let personClassObject = NSKeyedUnarchiver.unarchiveObjectWithFile(HelperClass.path()) as? HelperClass
////        
////        return personClassObject?.person
//        return nil
//    }
}
