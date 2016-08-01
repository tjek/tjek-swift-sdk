//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation


// TODO: Remove concept of `event` from pool... just have a 'poolable' object that has a uuid:String
// TODO: move disk-caching responsibility out of the pool. It's up to person passing in poolable object to know how to cache that type of obj

typealias SerializedEvent = [String:AnyObject]

class EventsPool {
    typealias EventShipperCompletion = (shippedEventIds:[String]?) -> Void
    typealias EventShipper = (serializedEvents:[SerializedEvent], completion:EventShipperCompletion) -> Void
    
    
    init(flushTimeout:Int, flushLimit:Int, eventShipper:EventShipper) {
        self.flushTimeout = flushTimeout
        self.flushLimit = flushLimit
        self._eventShipperBlock = eventShipper
        self._pendingEvents = []
        
        dispatch_async(_poolQueue) {
            // read pending events from disk.
            if let diskEvents = EventsPool.getPendingEventsFromDisk() where diskEvents.count > 0 {
                // add disk events to head of pending events
                self._pendingEvents.insertContentsOf(diskEvents, at: 0)
            }
            
            if self.shouldFlushEvents() {
                self.flushPendingEvents()
            } else {
                self.startTimerIfNeeded()
            }
        }
    }
    
    func pushEvent(event:SerializedEvent) {
        dispatch_async(_poolQueue) {
            // add serialized event to pending-events
            self._pendingEvents.append(event)
            
            // need to wait until first initialization
            EventsPool.savePendingEventsToDisk(self._pendingEvents)
            
            print("[pool] push pending:\(self._pendingEvents.count) \(event["id"])")
            
            // flush any pending events (only if limit reached)
            self.flushPendingEventsIfNeeded()
        }
    }
    
    var flushLimit:Int {
        didSet {
            dispatch_async(_poolQueue) {
                // check if we need to flush after limit changed
                self.flushPendingEventsIfNeeded()
            }
        }
    }
    var flushTimeout:Int {
        didSet {
            dispatch_async(_poolQueue) {
                // restart timer when timeout is changed
                self.restartTimerIfNeeded()
            }
        }
    }
    
    
    
    
    // MARK: - Private
    
    private let _poolQueue:dispatch_queue_t = dispatch_queue_create("com.shopgun.ios.sdk.events_pool.queue", DISPATCH_QUEUE_SERIAL)
    private var _pendingEvents:[SerializedEvent]
    
    
    
    // MARK: - Flushing
    
    private var _isFlushing:Bool = false
    private let _eventShipperBlock:EventShipper
    
    
    private func flushPendingEventsIfNeeded() {
        if self.shouldFlushEvents() {
            self.flushPendingEvents()
        }
    }
    private func flushPendingEvents() {
        // currently flushing. no-op
        guard _isFlushing == false else {
            return
        }
        // nothing to flush. no-op
        guard _pendingEvents.count > 0 else {
            return
        }
        
        _isFlushing = true
        
        // stop any running timer (will be restarted on completion)
        _flushTimer?.invalidate()
        _flushTimer = nil
        
        
        // get the events that
        let eventsToShip:[SerializedEvent] = _pendingEvents
        
        // pass the serialized events to the eventShipper (on a bg queue)
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            self._eventShipperBlock(serializedEvents: eventsToShip) {
                [unowned self] shippedEventIds in
                
                // perform completion in pool's queue
                dispatch_async(self._poolQueue) {
                    
                    // only if we receive some shipped events back (eg. no network error)
                    // we are going to trim the pending events queue of all the events that were successfully received
                    if shippedEventIds != nil {
                        
                        var mutableShippedIds = shippedEventIds!
                        
                        let trimmedEvents = self._pendingEvents.filter {
                            if mutableShippedIds.count > 0,
                                let eventId:String = $0["id"] as? String,
                                let idx = mutableShippedIds.indexOf(eventId) {
                                
                                mutableShippedIds.removeAtIndex(idx)
                                return false
                            }
                            return true
                        }
                        
                        // something changed in the pending events - sync back to memory (and disk) cache
                        if trimmedEvents.count != self._pendingEvents.count {
                            self._pendingEvents = trimmedEvents
                            EventsPool.savePendingEventsToDisk(self._pendingEvents)
                        }
                    } else {
                        // TODO: possibly scale back timeout if regularly getting network error
                        // Also, if maybe have a way to handle pendingEvents count getting really large? Just clear old events on init if > big_number
                    }
                    
                    self._isFlushing = false
                    
                    
                    // start the timer
                    self.startTimerIfNeeded()
                }
            }
        }
    }
    
    private func shouldFlushEvents() -> Bool {
        if _isFlushing {
            return false
        }
        
        // if pool size >= flushLimit
        if _pendingEvents.count >= flushLimit {
            return true
        }
        
        return false
    }



    
    
    // MARK: - Timer
    
    private var _flushTimer:NSTimer?
    
    private func restartTimerIfNeeded() {
        guard _flushTimer?.timeInterval != Double(flushTimeout) else {
            return
        }
        
        _flushTimer?.invalidate()
        _flushTimer = nil
        
        startTimerIfNeeded()
    }
    
    private func startTimerIfNeeded() {
        guard _flushTimer == nil && _isFlushing == false else {
            return
        }
        
        // generate a new timer. needs to be performed on main runloop
        _flushTimer = NSTimer(timeInterval:Double(flushTimeout), target:self, selector:#selector(EventsPool.flushTimerTick(_:)), userInfo:nil, repeats:true)
        NSRunLoop.mainRunLoop().addTimer(_flushTimer!, forMode: NSRunLoopCommonModes)        
    }
    
    @objc private func flushTimerTick(timer:NSTimer?) {
        // called from main runloop
        dispatch_async(_poolQueue) {
            self.flushPendingEvents()
        }
    }

    
    
    
    // MARK: - Disk cache
    
    private static let _diskCachePath:String? = {
        let fileName = "com.shopgun.ios.sdk.events_pool.disk_cache.plist"
        return (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first as NSString?)?.stringByAppendingPathComponent(fileName)
    }()
    
    private static func savePendingEventsToDisk(events:[SerializedEvent]) {
        guard _diskCachePath != nil else {
            return
        }
        
        let contents = ["events":events] as NSDictionary
        contents.writeToFile(_diskCachePath!, atomically: true)
    }
    
    private static func getPendingEventsFromDisk() -> [SerializedEvent]? {
        guard _diskCachePath != nil else {
            return nil
        }
        
        let contents = NSDictionary(contentsOfFile: _diskCachePath!) as? [String:AnyObject]
        if let events = contents?["events"] as? [SerializedEvent] {
            return events
        }
        
        return nil
    }
}