///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

/// The only thing a cached object _NEEDS_ is to be codable, and have a cacheId
protocol CacheableEvent: Codable {
    var cacheId: String { get }
}

/// A class that handles the Caching of the events to disk
class EventsCache<T: CacheableEvent> {
    
    let diskCachePath: URL?
    let maxCount: Int
    
    // If directory is nil, it will never cache to disk, only to memory.
    init(fileName: String, directory: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, maxCount: Int = 1000) {
        self.diskCachePath = directory?.appendingPathComponent(fileName)
        self.maxCount = maxCount
    }
    
    /// Note - this property is syncronized with memory writes, so may not be instantaneous
    var objectCount: Int {
        return self.cacheInMemoryQueue.sync {
            self.allObjects.count
        }
    }
    
    /// Lazily initialize from the disk. this may take a while, so the beware the first call to allObjects
    lazy fileprivate var allObjects: [T] = {
        return self.cacheOnDiskQueue.sync {
            let objs = self.retreiveFromDisk() ?? []
            if objs.count > self.maxCount {
                return Array(objs.suffix(self.maxCount))
            }
            return objs
            
        }
    }()
    
    func write(toTail objects: [T]) {
        guard objects.count > 0 else { return }
        
        cacheInMemoryQueue.async {
            
            self.allObjects = Array((self.allObjects + objects).suffix(self.maxCount))
            
            self.requestWriteToDisk()
        }
    }
    
    func read(fromHead count: Int) -> [T] {
        return self.cacheInMemoryQueue.sync {
            Array(self.allObjects.prefix(count))
        }
    }
    
    func remove(ids: [String]) {
        guard ids.count > 0 else { return }
        
        cacheInMemoryQueue.async {
            self.allObjects = self.allObjects.filter { ids.contains($0.cacheId) == false }
            
            self.requestWriteToDisk()
        }
    }
    
    fileprivate var writeToDiskTimer: Timer?
    fileprivate var writeRequestCount: Int = 0
    
    fileprivate let cacheInMemoryQueue: DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.events_cache.memory_queue", attributes: [])
    fileprivate let cacheOnDiskQueue: DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.events_cache.disk_queue", attributes: [])
    
    fileprivate func requestWriteToDisk() {
        writeRequestCount += 1
        
        if writeToDiskTimer == nil {
            writeToDiskTimer = Timer(timeInterval: 0.2, target: self, selector: #selector(writeToDiskTimerTick(_:)), userInfo: nil, repeats: false)
            RunLoop.main.add(writeToDiskTimer!, forMode: RunLoop.Mode.common)
        }
    }
    @objc fileprivate func writeToDiskTimerTick(_ timer: Timer) { writeCurrentStateToDisk() }
    
    fileprivate func writeCurrentStateToDisk() {
        cacheInMemoryQueue.async {
            
            let objsToSave = self.allObjects
            let currentWriteRequestCount = self.writeRequestCount
            
            self.cacheOnDiskQueue.async {
                
                self.saveToDisk(objects: objsToSave)
                
                // something has changed while we were writing to disk - write again!
                if currentWriteRequestCount != self.writeRequestCount {
                    self.writeCurrentStateToDisk()
                } else {
                    // reset timer so that another request can be made
                    self.writeToDiskTimer = nil
                }
            }
        }
    }
    
    fileprivate func retreiveFromDisk() -> [T]? {
        guard let fileURL = diskCachePath else { return nil }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? PropertyListDecoder().decode([T].self, from: data)
    }
    
    fileprivate func saveToDisk(objects: [T]) {
        guard let fileURL = diskCachePath else { return }
        
        guard let encodedData: Data = try? PropertyListEncoder().encode(objects) else {
            return
        }
        
        try? encodedData.write(to: fileURL)
    }
}
