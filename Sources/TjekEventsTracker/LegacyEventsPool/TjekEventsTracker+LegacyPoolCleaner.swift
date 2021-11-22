///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

extension TjekEventsTracker {
    /// A function that uses the old legacy Cache, Pool, & Shipper, to send any pending legacy events, using the old system.
    static func legacyPoolCleaner(
        cache: EventsCache_v1 = EventsCache_v1(fileName: "com.shopgun.ios.sdk.events_pool.disk_cache.plist"),
        dispatchInterval: TimeInterval = 5, baseURL: URL, enabled: Bool, completion: @escaping (_ shippedCount: Int) -> Void) {
        DispatchQueue.global().async {
            let shippedCount: Int = cache.objectCount
            guard shippedCount > 0 else {
                completion(shippedCount)
                return
            }
            
            let eventsShipper = EventsShipper_v1(baseURL: baseURL,
                                                 dryRun: !enabled)
            
            var legacyPool: EventsPool_v1? = EventsPool_v1(dispatchInterval: dispatchInterval,
                                                           dispatchLimit: 0,
                                                           shipper: eventsShipper,
                                                           cache: cache)
            
            // hold on to the legacy pool until there are no more events to flush, at which
            legacyPool?.willFlushCallback = { objsToFlush in
                if objsToFlush.isEmpty {
                    completion(shippedCount)
                    legacyPool = nil
                }
            }
        }
    }
}
