//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation


@objc(SGNEventsTracker)
public class EventsTracker : NSObject {
    
    // MARK: Instance properties & methods
    
    public let trackId:String
    
    public init(trackId:String) {
        self.trackId = trackId
    }
    
    public func trackEvent(_ type:String) {
        trackEvent(type, properties: nil)
    }
    public func trackEvent(_ type:String, properties:[String:AnyObject]?) {
        track(event: Event(type:type, trackId:trackId, properties:properties, personId:personId, viewContext:_currentViewContext, campaignContext:_currentCampaignContext))
    }
    func track(event:EventsTracker.Event) {
        // make sure that all events are initially triggered on the main thread, to guarantee order. 
        DispatchQueue.main.async {
            EventsTracker.pool.push(object: event)
        }
    }
    
    /// The optional PersonId that will be sent with every event
    public var personId:String?
    
    
    /// Allows the client to attach view information to all future events.
    public func updateView(_ path:[String]? = nil, uri:String? = nil, previousPath:[String]? = nil) {
        
        if path == nil && previousPath == nil && uri == nil {
            _currentViewContext = nil
        }
        else {
            _currentViewContext = Context.ViewContext(path:path, previousPath: previousPath, uri: uri)
        }
    }
    fileprivate var _currentViewContext:Context.ViewContext?
    
    
    /// Allows the client to attach campaign information to all future events
    public func updateCampaign(name:String? = nil, source:String? = nil, medium:String? = nil, term:String? = nil, content:String? = nil) {
        if name == nil && source == nil && medium == nil && term == nil && content == nil {
            _currentCampaignContext = nil
        } else {
            _currentCampaignContext = Context.CampaignContext(name:name, source: source, medium: medium, term: term, content: content)
        }
    }
    fileprivate var _currentCampaignContext:Context.CampaignContext?
    
    
    
    
    
    
    // MARK: - Static properties & methods
    
    
    public static var globalTracker:EventsTracker? {
        if _globalTracker == nil, let trackId = self.globalTrackId {
            _globalTracker = EventsTracker(trackId: trackId)
        }
        return _globalTracker
    }
    fileprivate static var _globalTracker:EventsTracker?
    
    
    public static var globalTrackId : String? {
        get {
            if _globalTrackId == nil {
                _globalTrackId = Utils.fetchConfigValue(for:"TrackId") as? String
            }
            
            if _globalTrackId == nil {
                // FIXME: only print once.
                print("You must define a ShopGun `TRACK_ID` in your ShopGunSDK-Info.plist, or with `ShopGunSDK.EventsTracker.globalTrackId = ...`")
                // TODO: more details in error message.
                // TODO: maybe consider asserting?
                // assert(_trackId != nil, "You must define a ShopGun `TrackId` in your info.plist, or with `EventsTracker.trackId = ...`")
            }
            
            return _globalTrackId
        }
        set {
            if _globalTracker?.trackId != newValue {
                _globalTracker = nil
            }
            _globalTrackId = newValue
        }
    }
    fileprivate static var _globalTrackId : String?
    
    
    
    
    public static func trackEvent(_ type:String) {
        trackEvent(type, properties: nil)
    }
    public static func trackEvent(_ type:String, properties:[String:AnyObject]?) {
        globalTracker?.trackEvent(type, properties: properties)
    }
    
    
    
    // MARK: Global Properties
    
    public static var dispatchInterval:TimeInterval {
        get { return pool.dispatchInterval }
        set { pool.dispatchInterval = newValue }
    }
    public static var dispatchLimit:Int {
        get { return pool.dispatchLimit }
        set { pool.dispatchLimit = newValue }
    }
    
    public static var baseURL:URL {
        get { return (pool.shipper as! EventsShipper).baseURL }
        set { (pool.shipper as! EventsShipper).baseURL = newValue }
    }
    
    public static var dryRun:Bool {
        get { return (pool.shipper as! EventsShipper).dryRun }
        set { (pool.shipper as! EventsShipper).dryRun = newValue }
    }
    
    
    
    
    // MARK: - Pool
    
    fileprivate static var pool:CachedFlushablePool = CachedFlushablePool(dispatchInterval: 120, dispatchLimit: 100,
                                                                          shipper: EventsShipper(baseURL:URL(string: "https://events.shopgun.com")!),
                                                                          cache: EventsCache(fileName:"com.shopgun.ios.sdk.events_pool.disk_cache.plist"))
    
    
    /// A class that handles the shipping of the Events
    fileprivate class EventsShipper : PoolShipperProtocol {
        
        var baseURL:URL
        
        /// If true we dont really ship events, just pretend like it was successful
        var dryRun:Bool = false
        
        init(baseURL:URL) {
            self.baseURL = baseURL
        }
        
        fileprivate static let networkSession:URLSession = {
            return URLSession(configuration: URLSessionConfiguration.default)
        }()
        
        
        fileprivate func ship(objects: [SerializedPoolObject], completion: @escaping ((_ poolIdsToRemove:[String]) -> Void)) {
            
            var orderedEventDicts:[[String:AnyObject]] = []
            var keyedEventDicts:[String:[String:AnyObject]] = [:]
            
            var allIds:[String] = []
            var idsToRemove:[String] = []
            
            for obj in objects {
                allIds.append(obj.poolId)
                
                // deserialize the jsonData and update the sent date
                if var jsonDict = try? JSONSerialization.jsonObject(with: obj.jsonData, options: []) as? [String:AnyObject],
                    jsonDict != nil {

                    jsonDict!["sentAt"] = Utils.ISO8601_dateFormatter.string(from: Date()) as AnyObject?
                    
                    orderedEventDicts.append(jsonDict!)
                    keyedEventDicts[obj.poolId] = jsonDict!
                }
                else {
                    idsToRemove.append(obj.poolId)
                }
            }
            
            //eject if in dryRun mode
            guard dryRun == false else {
                completion(allIds)
                return
            }
            
            // place array of dictionaries under 'events' key
            let jsonDict = ["events": orderedEventDicts]
            
            // convert the objects to json (or msgpack in the future)
            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options:[]) else {
                // unable to serialize jsonDict... tell pool to remove all objects
                completion(allIds)
                return
            }
            
            let url = baseURL.appendingPathComponent("track")
            
            var request = URLRequest(url:url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = jsonData

            
            // print("[SHIPPER] shipping \(orderedEventDicts.count) events (\(String(format:"%.3f", Double(jsonData.count) / 1024.0)) kb)")
            
            
            // actually do the shipping of the events
            EventsShipper.networkSession.dataTask(with: request) {
                (data, response, error) in
                
                // try to parse the response from the server.
                // if it is unreadable we will just tell pool to remove just the non-event objects
                if data != nil,
                    let jsonData = try? JSONSerialization.jsonObject(with: data!, options:[]) as? [String:AnyObject],
                    let events = jsonData!["events"] as? [[String:AnyObject]] {
                    
                    // go through all the returned event statuses, figuring out which can be removed from the pool
                    for eventData in events {
                        if let uuid = eventData["id"] as? String,
                            let status = eventData["status"] as? String {
                            
                            // send back all event Ids that where received (even if they were errors)
                            // only skip those that where not recieved (nack)
                            if status != "nack" {
                                idsToRemove.append(uuid)
                            }
                            else {
                                // nack - check the age of the event, and kill it if it's really old
                                let maxAge:Double = 60*60*24*7 // 1 week
                                if let recordedDateStr = keyedEventDicts[uuid]?["recordedAt"] as? String,
                                    let recordedDate = Utils.ISO8601_dateFormatter.date(from: recordedDateStr),
                                    recordedDate.timeIntervalSinceNow < -maxAge {
                                    idsToRemove.append(uuid)
                                }
                            }
                        }
                    }
                }
                completion(idsToRemove)
            }.resume()
        }
    }
    
    
    /// A class that handles the Caching of the events to disk
    fileprivate class EventsCache : PoolCacheProtocol {
        
        let diskCachePath:String?
        
        init(fileName:String) {
            self.diskCachePath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString?)?.appendingPathComponent(fileName)
        }
        
        var objectCount: Int {
            return allObjects.count
        }
        
        let maxCount:Int = 1000
        
        /// Lazily initialize from the disk. this may take a while, so the beware the first call to allObjects
        lazy fileprivate var allObjects:[SerializedPoolObject] = {
            let start = Date().timeIntervalSinceReferenceDate
            
            var objs:[SerializedPoolObject] = []
            objs.reserveCapacity(self.maxCount)
            
            self.cacheOnDiskQueue.sync {
                objs = self.retreiveFromDisk() ?? []
            }
            //print("[CACHE] INIT \(objs.count) objs: \(String(format:"%.4f", Date().timeIntervalSinceReferenceDate - start)) secs")
            return objs
        }()
        

        func write(toTail objects: [SerializedPoolObject]) {
            guard objects.count > 0 else { return }
            
            //let start = Date().timeIntervalSinceReferenceDate
            
            cacheInMemoryQueue.async {
                // remove from head of array to maintain a max size
                let currentCount = self.allObjects.count + objects.count
                if currentCount > self.maxCount {
                    self.allObjects.removeFirst(currentCount - self.maxCount)
                }
                
                // update in-memory version
                self.allObjects.append(contentsOf: objects)
                
                //print("[CACHE] WRITE [\(self.writeRequestCount+1)] \(self.allObjects.count) objs: \(String(format:"%.4f", Date().timeIntervalSinceReferenceDate - start)) secs")
                
                self.requestWriteToDisk()
            }
        }
        
        func read(fromHead count: Int) -> [SerializedPoolObject] {
            
            var objs:[SerializedPoolObject] = []
            
            cacheInMemoryQueue.sync {
                let lastIndex = min(self.allObjects.endIndex, count) - 1
                if lastIndex > 0 {
                    objs = Array(self.allObjects[0 ... lastIndex])
                }
            }
            
            return objs
        }
        
        func remove(poolIds: [String]) {
            guard poolIds.count > 0 else { return }
            
            //let start = Date().timeIntervalSinceReferenceDate
            
            cacheInMemoryQueue.async {
                var idsToRemove = poolIds
                
                var trimmedObjs:[SerializedPoolObject] = []
                trimmedObjs.reserveCapacity(self.maxCount)
                
                for (index, obj) in self.allObjects.enumerated() {
                    // it should be ignored, skip this object
                    if let idx = idsToRemove.index(of: obj.poolId) {
                        idsToRemove.remove(at: idx)
                        // it was the last id to remove, so just append all the rest
                        if idsToRemove.count == 0 {
                            let allObjCount = self.allObjects.count
                            if (index+1) < allObjCount {
                                trimmedObjs.append(contentsOf: self.allObjects[index+1 ..< allObjCount])
                            }
                            break
                        }
                    }
                    else {
                        trimmedObjs.append(obj)
                    }
                }
                
                self.allObjects = trimmedObjs
                
                //print("[CACHE] REMOVE [\(self.writeRequestCount+1)] \(poolIds.count) objs: \(String(format:"%.4f", Date().timeIntervalSinceReferenceDate - start)) secs")
                self.requestWriteToDisk()
            }
        }
        
        
        var writeToDiskTimer:Timer? = nil
        var writeRequestCount:Int = 0
        
        fileprivate let cacheInMemoryQueue:DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.events_cache.memory_queue", attributes: [])
        fileprivate let cacheOnDiskQueue:DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.events_cache.disk_queue", attributes: [])
        
        fileprivate func requestWriteToDisk() {
            writeRequestCount += 1

            if writeToDiskTimer == nil {
                //print ("[CACHE] request write to disk [\(writeRequestCount)]")
                
                writeToDiskTimer = Timer(timeInterval:0.2, target:self, selector:#selector(writeToDiskTimerTick(_:)), userInfo:nil, repeats:false)
                RunLoop.main.add(writeToDiskTimer!, forMode: RunLoopMode.commonModes)
            }
        }
        @objc fileprivate func writeToDiskTimerTick(_ timer:Timer) { writeCurrentStateToDisk() }
        
        
        fileprivate func writeCurrentStateToDisk() {
            
            //let start = Date().timeIntervalSinceReferenceDate
            
            cacheInMemoryQueue.async {
                
                let objsToSave = self.allObjects
                guard objsToSave.count > 0 else {
                    return
                }
                
                let currentWriteRequestCount = self.writeRequestCount
                
                //print("[CACHE] SAVING [\(currentWriteRequestCount)] \(objsToSave.count) objs to disk")
                
                self.cacheOnDiskQueue.async {
                    
                    self.saveToDisk(objects:objsToSave)
                    
                    //print("[CACHE] SAVED [\(currentWriteRequestCount)] \(objsToSave.count) objs to disk: \(String(format:"%.4f", Date().timeIntervalSinceReferenceDate - start)) secs")
                    
                    // something has changed while we were writing to disk - write again!
                    if currentWriteRequestCount != self.writeRequestCount {
                        self.writeCurrentStateToDisk()
                    }
                    else {
                        // reset timer so that another request can be made
                        self.writeToDiskTimer = nil
                        //print("[CACHE] no pending write requests")
                    }
                }
            }
        }
        
        
        fileprivate func retreiveFromDisk() -> [SerializedPoolObject]? {
            guard let path = diskCachePath else { return nil }
            
            if let objDicts = NSArray(contentsOfFile: path) {
                
                // map [[String:AnyObject]] -> [(poolId, jsonData)]
                var serializedObjs:[SerializedPoolObject] = []
                for arrData in objDicts {
                    if let objDict = (arrData as? [String:AnyObject])?.first,
                        let jsonData = objDict.value as? Data {
                        serializedObjs.append((objDict.key, jsonData))
                    }
                }

                return serializedObjs
            }
            return nil
        }
        
        fileprivate func saveToDisk(objects:[SerializedPoolObject]) {
            guard let path = diskCachePath else { return }
            
            // map [(poolId, jsonData)] -> [[String:AnyObject]]
            let objDicts:[[String:AnyObject]] = objects.map { (object:SerializedPoolObject) in
                return [object.poolId: object.jsonData as AnyObject]
            }
            
            (objDicts as NSArray).write(toFile: path, atomically: true)
        }
    }
    
    
    /// This is a concrete implementation of an Event.
    // It defines everything that an event, as seen by the server
    class Event {
        
        let version:String = "1.0.0"
        
        let type:String
        let trackId:String
        let properties:[String:AnyObject]?
        let uuid:String
        let recordedDate:Date
        let clientId:String
        let sessionId:String
        
        // optional context properties
        let viewContext:EventsTracker.Context.ViewContext?
        let campaignContext:EventsTracker.Context.CampaignContext?
        let personId:String?
        
        init(type:String,
             trackId:String,
             properties:[String:AnyObject]? = nil,
             uuid:String = UUID().uuidString,
             recordedDate:Date = Date(),
             clientId:String = SDKConfig.clientId,
             sessionId:String = SDKConfig.sessionId,
             personId:String? = nil,
             viewContext:EventsTracker.Context.ViewContext? = nil,
             campaignContext:EventsTracker.Context.CampaignContext? = nil) {
            
            self.type = type
            self.trackId = trackId
            self.properties = properties
            self.uuid = uuid
            self.recordedDate = recordedDate
            self.clientId = clientId
            self.sessionId = sessionId
            self.viewContext = viewContext
            self.campaignContext = campaignContext
            self.personId = personId
        }
    }
   
}



// Make the Event work with the pool
extension EventsTracker.Event : PoolableObject {
    
    var poolId:String {
        return self.uuid
    }
    
    /// Allow the Event to be converted to a dictionary, for JSONification
    func serialize() -> SerializedPoolObject? {
        
        var dict:[String:AnyObject] = [:]
        
        dict["type"] = type as AnyObject? // required
        
        dict["id"] = uuid as AnyObject // required
        dict["version"] = version as AnyObject  // required
        dict["recordedAt"] = Utils.ISO8601_dateFormatter.string(from: recordedDate) as AnyObject?  // required, but if date is invalid we want server to warn
        
        // client - required
        let clientDict:[String:String] = ["id": clientId, "trackId": trackId]
        dict["client"] = clientDict as AnyObject
        
        // context - required
        let contextDict:[String:AnyObject] = EventsTracker.Context.toDictionary(sessionId:sessionId, personId:personId, viewContext:viewContext, campaignContext:campaignContext) ?? [:]
        dict["context"] = contextDict as AnyObject
        
        // properties - required
        let propertiesDict:[String:AnyObject] = prepareForJSON(properties as AnyObject?) as? [String : AnyObject] ?? [:]
        dict["properties"] = propertiesDict as AnyObject
        
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options:[]) else {
            return nil
        }
        
        return (poolId, jsonData)
    }
}





/// Given arbitrary properties, this will remove those that cant be converted to JSON values, and parse Dates where appropriate.
fileprivate func prepareForJSON(_ property:AnyObject?)->AnyObject? {
    
    guard let prop = property else { return nil }
    
    switch prop {
    case is Int,
         is Double, is Float,
         is NSNumber,
         is NSNull,
         is String, is NSString:
        return prop
    case is Array<AnyObject>:
        var result:[AnyObject]? = nil
        for val in (prop as! Array<AnyObject>) {
            if let cleanVal = prepareForJSON(val) {
                if result == nil { result = [] }
                result?.append(cleanVal)
            }
        }
        return result as AnyObject?
    case is Dictionary<String,AnyObject>:
        var result:[String:AnyObject]? = nil
        for (key, val) in (prop as! Dictionary<String,AnyObject>) {
            if let cleanVal = prepareForJSON(val) {
                if result == nil { result = [:] }
                result?[key] = cleanVal
            }
        }
        return result as AnyObject?
    case is Date:
        return Utils.ISO8601_dateFormatter.string(from: prop as! Date) as AnyObject?
    default:
        return nil
    }
}




/// A standard event protocol. Any object that claims to be an event must conform at the very least to this protocol.
@objc(SGNEventProtocol)
public protocol EventProtocol {
    var type:String { get }
    var properties:[String:AnyObject]? { get }
}

public extension EventProtocol {
    
    // make properties optional
    var properties:[String:AnyObject]? {
        return nil
    }
    
}

public extension EventProtocol {
    // utility track method
    func track(with tracker:EventsTracker? = EventsTracker.globalTracker) {
        guard let t = tracker else {
            // trying to track an event without a tracker. WARN?
            return
        }
        t.track(event: self)
    }
}

public extension EventsTracker {
    func track(event:EventProtocol) {
        self.trackEvent(event.type, properties: event.properties)
    }
}
