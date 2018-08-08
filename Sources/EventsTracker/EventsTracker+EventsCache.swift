//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension EventsTracker {
    
    /// A class that handles the Caching of the events to disk
    class EventsCache_v1: PoolCacheProtocol {
        
        let diskCachePath: String?
        
        init(fileName: String) {
            self.diskCachePath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString?)?.appendingPathComponent(fileName)
        }
        
        /// Note - this property is syncronized with memory writes, so may not be instantaneous
        var objectCount: Int {
            var count: Int = 0
            cacheInMemoryQueue.sync {
                count = allObjects.count
            }
            return count
        }
        
        let maxCount: Int = 1000
        
        /// Lazily initialize from the disk. this may take a while, so the beware the first call to allObjects
        lazy fileprivate var allObjects: [SerializedPoolObject] = {
            let start = Date().timeIntervalSinceReferenceDate
            
            var objs: [SerializedPoolObject] = []
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
            
            var objs: [SerializedPoolObject] = []
            
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
                
                var trimmedObjs: [SerializedPoolObject] = []
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
                    } else {
                        trimmedObjs.append(obj)
                    }
                }
                
                self.allObjects = trimmedObjs
                
                //print("[CACHE] REMOVE [\(self.writeRequestCount+1)] \(poolIds.count) objs: \(String(format:"%.4f", Date().timeIntervalSinceReferenceDate - start)) secs")
                self.requestWriteToDisk()
            }
        }
        
        var writeToDiskTimer: Timer?
        var writeRequestCount: Int = 0
        
        fileprivate let cacheInMemoryQueue: DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.events_cache.memory_queue", attributes: [])
        fileprivate let cacheOnDiskQueue: DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.events_cache.disk_queue", attributes: [])
        
        fileprivate func requestWriteToDisk() {
            writeRequestCount += 1
            
            if writeToDiskTimer == nil {
                //print ("[CACHE] request write to disk [\(writeRequestCount)]")
                
                writeToDiskTimer = Timer(timeInterval: 0.2, target: self, selector: #selector(writeToDiskTimerTick(_:)), userInfo: nil, repeats: false)
                RunLoop.main.add(writeToDiskTimer!, forMode: RunLoopMode.commonModes)
            }
        }
        @objc fileprivate func writeToDiskTimerTick(_ timer: Timer) { writeCurrentStateToDisk() }
        
        fileprivate func writeCurrentStateToDisk() {
            
            //let start = Date().timeIntervalSinceReferenceDate
            
            cacheInMemoryQueue.async {
                
                let objsToSave = self.allObjects
                
                let currentWriteRequestCount = self.writeRequestCount
                
                //print("[CACHE] SAVING [\(currentWriteRequestCount)] \(objsToSave.count) objs to disk")
                
                self.cacheOnDiskQueue.async {
                    
                    self.saveToDisk(objects: objsToSave)
                    
                    //print("[CACHE] SAVED [\(currentWriteRequestCount)] \(objsToSave.count) objs to disk: \(String(format:"%.4f", Date().timeIntervalSinceReferenceDate - start)) secs")
                    
                    // something has changed while we were writing to disk - write again!
                    if currentWriteRequestCount != self.writeRequestCount {
                        self.writeCurrentStateToDisk()
                    } else {
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
                var serializedObjs: [SerializedPoolObject] = []
                for arrData in objDicts {
                    if let objDict = (arrData as? [String: AnyObject])?.first,
                        let jsonData = objDict.value as? Data {
                        serializedObjs.append((objDict.key, jsonData))
                    }
                }
                
                return serializedObjs
            }
            return nil
        }
        
        fileprivate func saveToDisk(objects: [SerializedPoolObject]) {
            guard let path = diskCachePath else { return }
            
            // map [(poolId, jsonData)] -> [[String:AnyObject]]
            let objDicts: [[String: AnyObject]] = objects.map { (object: SerializedPoolObject) in
                return [object.poolId: object.jsonData as AnyObject]
            }
            
            (objDicts as NSArray).write(toFile: path, atomically: true)
        }
    }
}
