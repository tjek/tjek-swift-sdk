//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation

class EventsPool {
    
    typealias EventShippingHandler<T> = ([T], @escaping ([String: EventShipperResult]) -> Void) -> Void

    let dispatchInterval: TimeInterval
    let dispatchLimit: Int
    let shippingHandler: EventShippingHandler<ShippableEvent>
    let cache: EventsCache<ShippableEvent>
    
    init(dispatchInterval: TimeInterval,
         dispatchLimit: Int,
         shippingHandler: @escaping EventShippingHandler<ShippableEvent>,
         cache: EventsCache<ShippableEvent>)
    {
        
        self.dispatchInterval = dispatchInterval
        self.dispatchLimit = dispatchLimit
        self.shippingHandler = shippingHandler
        self.cache = cache
        
        poolQueue.async {
            // start flushing the cache on creation
            if self.shouldFlushEvents() {
                self.flushPendingEvents()
            } else {
                self.startTimerIfNeeded()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground(_:)), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    /// Add an object to the pool
    func push(event: ShippableEvent) {
        Logger.log("[Pool] Pushing \(event.id)", level: .important, source: .EventsTracker)

        poolQueue.async {
            // add the object to the tail of the cache
            self.cache.write(toTail: [event])
            
            // flush any pending events (only if limit reached)
            if self.shouldFlushEvents() {
                self.flushPendingEvents()
            } else {
                self.startTimerIfNeeded()
            }
        }
    }
    
    // MARK: - Private
    
    fileprivate var dispatchIntervalDelay: TimeInterval = 0
    
    fileprivate let poolQueue: DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.pool.queue", attributes: [])
    
    @objc
    private func appDidEnterBackground(_ notification: Notification) {
        poolQueue.async { [weak self] in
            self?.flushPendingEvents()
        }
    }
    
    // MARK: - Flushing
    
    fileprivate var isFlushing: Bool = false
    
    fileprivate func flushPendingEvents() {
        // currently flushing. no-op
        guard isFlushing == false else {
            return
        }

        let eventsToShip = self.cache.read(fromHead: self.dispatchLimit)
        
        // get the objects to be shipped
        guard eventsToShip.count > 0 else {
            return
        }
        
        isFlushing = true
        
        // stop any running timer (will be restarted on completion)
        flushTimer?.invalidate()
        flushTimer = nil
        
        // pass the objects to the shipper (on a bg queue)
        DispatchQueue.global(qos: .background).async { [weak self] in
            
            Logger.log("[Pool] Shipping \(eventsToShip.count) events", level: .important, source: .EventsTracker)
            
            self?.shippingHandler(eventsToShip) { [weak self] results in
                
                // perform completion in pool's queue (this will block events arriving until completed)
                self?.poolQueue.async { [weak self] in
                    self?.handleShipperResults(results)
                }
            }
        }
    }
    
    /// Handle the results recieved from the shipper. This will remove the successful & failed results from the cache, update the intervalDelay, and restart the timer
    private func handleShipperResults(_ results: [String: EventShipperResult]) {
        
        Logger.log("[Pool] Handling Results \(results)", level: .important, source: .EventsTracker)
        
        let idsToRemove: [String] = results.reduce([]) {
            switch $1.value {
            case .error, .success:
                return $0 + [$1.key]
            case .retry:
                return $0
            }
        }
        
        // remove the successfully shipped events
        self.cache.remove(ids: idsToRemove)
        
        // if no events are shipped then scale back the interval
        self.dispatchIntervalDelay = {
            if idsToRemove.count == 0 && self.dispatchInterval > 0 {
                let currentInterval = self.dispatchInterval + self.dispatchIntervalDelay
                
                let maxInterval: TimeInterval = 60 * 5 // 5 mins
                let newInterval = min(currentInterval * 1.1, maxInterval)
                
                return newInterval - self.dispatchInterval
            } else {
                return 0
            }
        }()
        
        self.isFlushing = false
        
        // start the timer
        self.startTimerIfNeeded()
    }
    
    fileprivate func shouldFlushEvents() -> Bool {
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
    
    fileprivate var flushTimer: Timer?
    
    fileprivate func startTimerIfNeeded() {
        guard flushTimer == nil && isFlushing == false && self.cache.objectCount > 0 else {
            return
        }
        
        let interval = dispatchInterval + dispatchIntervalDelay
        
        // generate a new timer. needs to be performed on main runloop
        flushTimer = Timer(timeInterval: interval, target: self, selector: #selector(flushTimerTick(_:)), userInfo: nil, repeats: false)
        RunLoop.main.add(flushTimer!, forMode: RunLoopMode.commonModes)
    }
    
    @objc fileprivate func flushTimerTick(_ timer: Timer?) {
        // called from main runloop
        poolQueue.async {
            self.flushTimer?.invalidate()
            self.flushTimer = nil
            self.flushPendingEvents()
        }
    }
}
