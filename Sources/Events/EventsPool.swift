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
    typealias EventShipperCompletion = (_ shippedEventIds:[String]?) -> Void
    typealias EventShipper = (_ serializedEvents:[SerializedEvent], _ completion:@escaping EventShipperCompletion) -> Void
    
    
    init(flushTimeout:Int, flushLimit:Int, eventShipper:@escaping EventShipper) {
        self.flushTimeout = flushTimeout
        self.flushLimit = flushLimit
        self._eventShipperBlock = eventShipper
        self._pendingEvents = []
        
        _poolQueue.async {
            // read pending events from disk.
            if let diskEvents = EventsPool.getPendingEventsFromDisk(), diskEvents.count > 0 {
                // add disk events to head of pending events
                self._pendingEvents.insert(contentsOf: diskEvents, at: 0)
            }
            
            if self.shouldFlushEvents() {
                self.flushPendingEvents()
            } else {
                self.startTimerIfNeeded()
            }
        }
    }
    
    func pushEvent(_ event:SerializedEvent) {
        _poolQueue.async {
            // add serialized event to pending-events
            self._pendingEvents.append(event)
            
            // need to wait until first initialization
            EventsPool.savePendingEventsToDisk(self._pendingEvents)
            
            // flush any pending events (only if limit reached)
            self.flushPendingEventsIfNeeded()
        }
    }
    
    var flushLimit:Int {
        didSet {
            _poolQueue.async {
                // check if we need to flush after limit changed
                self.flushPendingEventsIfNeeded()
            }
        }
    }
    var flushTimeout:Int {
        didSet {
            _poolQueue.async {
                // restart timer when timeout is changed
                self.restartTimerIfNeeded()
            }
        }
    }
    
    
    
    
    // MARK: - Private
    
    fileprivate let _poolQueue:DispatchQueue = DispatchQueue(label: "com.shopgun.ios.sdk.events_pool.queue", attributes: [])
    fileprivate var _pendingEvents:[SerializedEvent]
    
    
    
    // MARK: - Flushing
    
    fileprivate var _isFlushing:Bool = false
    fileprivate let _eventShipperBlock:EventShipper
    
    
    fileprivate func flushPendingEventsIfNeeded() {
        if self.shouldFlushEvents() {
            self.flushPendingEvents()
        }
    }
    fileprivate func flushPendingEvents() {
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
        DispatchQueue.global(qos:.background).async {
            self._eventShipperBlock(eventsToShip) { [unowned self] shippedEventIds in
                
                // perform completion in pool's queue
                self._poolQueue.async {
                    
                    // only if we receive some shipped events back (eg. no network error)
                    // we are going to trim the pending events queue of all the events that were successfully received
                    if shippedEventIds != nil {
                        
                        var mutableShippedIds = shippedEventIds!
                        
                        let trimmedEvents = self._pendingEvents.filter {
                            if mutableShippedIds.count > 0,
                                let eventId:String = $0["id"] as? String,
                                let idx = mutableShippedIds.index(of: eventId) {
                                
                                mutableShippedIds.remove(at: idx)
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
    
    fileprivate func shouldFlushEvents() -> Bool {
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
    
    fileprivate var _flushTimer:Timer?
    
    fileprivate func restartTimerIfNeeded() {
        guard _flushTimer?.timeInterval != Double(flushTimeout) else {
            return
        }
        
        _flushTimer?.invalidate()
        _flushTimer = nil
        
        startTimerIfNeeded()
    }
    
    fileprivate func startTimerIfNeeded() {
        guard _flushTimer == nil && _isFlushing == false else {
            return
        }
        
        // generate a new timer. needs to be performed on main runloop
        _flushTimer = Timer(timeInterval:Double(flushTimeout), target:self, selector:#selector(EventsPool.flushTimerTick(_:)), userInfo:nil, repeats:true)
        RunLoop.main.add(_flushTimer!, forMode: RunLoopMode.commonModes)        
    }
    
    @objc fileprivate func flushTimerTick(_ timer:Timer?) {
        // called from main runloop
        _poolQueue.async {
            self.flushPendingEvents()
        }
    }

    
    
    
    // MARK: - Disk cache
    
    fileprivate static let _diskCachePath:String? = {
        let fileName = "com.shopgun.ios.sdk.events_pool.disk_cache.plist"
        return (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString?)?.appendingPathComponent(fileName)
    }()
    
    fileprivate static func savePendingEventsToDisk(_ events:[SerializedEvent]) {
        guard _diskCachePath != nil else {
            return
        }
        
        let contents = ["events":events] as NSDictionary
        contents.write(toFile: _diskCachePath!, atomically: true)
    }
    
    fileprivate static func getPendingEventsFromDisk() -> [SerializedEvent]? {
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
