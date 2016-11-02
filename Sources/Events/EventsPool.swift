//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation

/// The format that is saved to the cache, and that is sent to the shipper.
/// This could be done in a better, more generic way, in the future
typealias SerializedPoolObject = (poolId:String, jsonData:Data)


/// Defines what an object that can be in the pool must be able to do
protocol PoolableObject {
    var poolId:String { get }
    
    func serialize() -> SerializedPoolObject?
}


/// Defines what a Pool's cache must be able to do.
/// Note that these act concurrently, so should be triggered on a bg thread.
protocol PoolCacheProtocol {
    
    var objectCount:Int { get }
    
    /// add the objects to the tail of the cache
    func write(toTail objects:[SerializedPoolObject])
    
    /// return the objects from head of cache. They only need to be shippable once they come out of the cache
    func read(fromHead count:Int) -> [SerializedPoolObject]
    
    /// run through the cache removing objects that have the specified ids
    func remove(poolIds:[String])
}

protocol PoolShipperProtocol {
    func ship(objects:[SerializedPoolObject], completion:@escaping ((_ poolIdsToRemove:[String])->Void))
}



class CachedFlushablePool {
    
    let shipper:PoolShipperProtocol
    let cache:PoolCacheProtocol
    
    var dispatchLimit:Int {
        didSet {
            _poolQueue.async {
                // check if we need to flush after limit changed
                self.flushPendingObjectsIfNeeded()
            }
        }
    }
    var dispatchInterval:TimeInterval
    
    fileprivate var dispatchIntervalDelay:TimeInterval = 0
    
    
    init(dispatchInterval:TimeInterval, dispatchLimit:Int, shipper:PoolShipperProtocol, cache:PoolCacheProtocol) {
        self.dispatchInterval = dispatchInterval
        self.dispatchLimit = dispatchLimit
        self.shipper = shipper
        self.cache = cache
        
        _poolQueue.async {
            // start flushing the cache on creation
            if self.shouldFlushObjects() {
                self.flushPendingObjects()
            } else {
                self.startTimerIfNeeded()
            }
        }
    }
    
    
    /// Add an object to the pool
    func push(object:PoolableObject) {
        //print("[POOL] pushing object")
        
        _poolQueue.async {
            
            if let serializedObj = object.serialize() {
                
                // add the object to the tail of the cache
                self.cache.write(toTail: [serializedObj])
                
                // flush any pending events (only if limit reached)
                self.flushPendingObjectsIfNeeded()
            }
        }
    }
    
    
    
    
    // MARK: - Private
    
    fileprivate let _poolQueue:DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.pool.queue", attributes: [])
    
    
    // MARK: - Flushing
    
    fileprivate var isFlushing:Bool = false
    
    
    fileprivate func flushPendingObjectsIfNeeded() {
        if self.shouldFlushObjects() {
            self.flushPendingObjects()
        }
    }
    fileprivate func flushPendingObjects() {
        // currently flushing. no-op
        guard isFlushing == false else {
            return
        }
        
        let objsToShip = self.cache.read(fromHead: self.dispatchLimit)
        
        // get the objects to be shipped
        guard objsToShip.count > 0 else {
            return
        }
        
        
        //print("[POOL] flushing \(objsToShip.count) objs")
        
        
        isFlushing = true
        
        // stop any running timer (will be restarted on completion)
        flushTimer?.invalidate()
        flushTimer = nil
        
        
        // pass the objects to the shipper (on a bg queue)
        DispatchQueue.global(qos:.background).async { [weak self] in
            
            self?.shipper.ship(objects: objsToShip) { [weak self] (poolIdsToRemove) in
                
                // perform completion in pool's queue (this will block events arriving until completed)
                self?._poolQueue.async { [weak self] in
                    guard let s = self else { return }
 
                    // remove the successfully shipped events
                    s.cache.remove(poolIds: poolIdsToRemove)
                    
                    
                    //print("[POOL] flushed \(poolIdsToRemove.count)/\(objsToShip.count)")
                    
                    // if no events are shipped then scale back the interval
                    if poolIdsToRemove.count == 0 {
                        if s.dispatchInterval > 0 {
                            let currentInterval = s.dispatchInterval + s.dispatchIntervalDelay
                            let maxInterval:TimeInterval = 60 * 5 // 5 mins
                            let newInterval = min(currentInterval * 1.1, maxInterval)
                            
                            s.dispatchIntervalDelay = newInterval - s.dispatchInterval
                        }
                    } else {
                        s.dispatchIntervalDelay = 0
                    }
                    
                    s.isFlushing = false
                    
                    // start the timer
                    s.startTimerIfNeeded()
                }
            }
        }
    }
    
    fileprivate func shouldFlushObjects() -> Bool {
        if isFlushing {
            return false
        }
        
        // if pool size >= dispatchLimit
        if self.cache.objectCount >= dispatchLimit {
            return true
        }
        
        return false
    }



    
    
    // MARK: - Timer
    
    fileprivate var flushTimer:Timer?
    
    fileprivate func startTimerIfNeeded() {
        guard flushTimer == nil && isFlushing == false && self.cache.objectCount > 0 else {
            return
        }
        
        let interval = dispatchInterval + dispatchIntervalDelay
        
        // generate a new timer. needs to be performed on main runloop
        flushTimer = Timer(timeInterval:interval, target:self, selector:#selector(flushTimerTick(_:)), userInfo:nil, repeats:false)
        RunLoop.main.add(flushTimer!, forMode: RunLoopMode.commonModes)
    }
    
    @objc fileprivate func flushTimerTick(_ timer:Timer?) {
        // called from main runloop
        _poolQueue.async {
            self.flushTimer?.invalidate()
            self.flushTimer = nil
            self.flushPendingObjects()
        }
    }
}
