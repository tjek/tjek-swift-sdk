//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit

// MARK: - Event Handling

extension PagedPublicationView {
    
    enum Events {
        case pageAppeared(pageNum:Int)
        case pageLoaded(pageNum:Int)
        case pageDisappeared(pageNum:Int)
        
        case pageSpreadChanged(newPageNums:[Int], oldPageNums:[Int])
        case pageSpreadZoomedIn(pageNums:[Int])
        case pageSpreadZoomedOut(pageNums:[Int])
        
        case pageTapped(pageNum:Int, location:CGPoint)
        case pageDoubleTapped(pageNum:Int, location:CGPoint)
        case pageLongPressed(pageNum:Int, location:CGPoint)
        
        
        func type() -> String {
            switch self {
            case .pageAppeared(_):
                return "pageAppeared"
            case .pageLoaded(_):
                return "pageLoaded"
            case .pageDisappeared(_):
                return "pageDisappeared"
            case .pageSpreadChanged(_):
                return "pageSpreadChanged"
            case .pageSpreadZoomedIn(_):
                return "pageSpreadZoomedIn"
            case .pageSpreadZoomedOut(_):
                return "pageSpreadZoomedOut"
            case .pageTapped(_):
                return "pageTapped"
            case .pageDoubleTapped(_):
                return "pageDoubleTapped"
            case .pageLongPressed(_):
                return "pageLongPressed"
            }
        }
        
        func properties() -> [String:AnyObject]? {
            switch self {
            case let .pageAppeared(pageNum):
                return ["pageNumber":pageNum as AnyObject]
            case let .pageLoaded(pageNum):
                return ["pageNumber":pageNum as AnyObject]
            case let .pageDisappeared(pageNum):
                return ["pageNumber":pageNum as AnyObject]
            case let .pageSpreadChanged(newPageNums, oldPageNums):
                return ["newPageNumbers":newPageNums as AnyObject,
                        "oldPageNumbers":oldPageNums as AnyObject]
            case let .pageSpreadZoomedIn(pageNum):
                return ["pageNumber":pageNum as AnyObject]
            case let .pageSpreadZoomedOut(pageNum):
                return ["pageNumber":pageNum as AnyObject]
            case let .pageTapped(pageNum, location):
                return ["pageNumber":pageNum as AnyObject,
                        "x":location.x as AnyObject,
                        "y":location.y as AnyObject]
            case let .pageDoubleTapped(pageNum, location):
                return ["pageNumber":pageNum as AnyObject,
                        "x":location.x as AnyObject,
                        "y":location.y as AnyObject]
            case let .pageLongPressed(pageNum, location):
                return ["pageNumber":pageNum as AnyObject,
                        "x":location.x as AnyObject,
                        "y":location.y as AnyObject]
            }
        }
        
        func trackEvent() {
            let type = self.type()
            let properties = self.properties()
            EventsTracker.trackEvent(type, properties: properties)
            
            print("[EVENT] \(type): \(properties)")
        }
    }
    
    
    
    func triggerEvent_PageAppeared(_ pageIndex:Int) {
        Events.pageAppeared(pageNum:pageIndex+1).trackEvent()
    }
    func triggerEvent_PageLoaded(_ pageIndex:Int,fromCache:Bool) {
        Events.pageLoaded(pageNum:pageIndex+1).trackEvent()
    }
    func triggerEvent_PageDisappeared(_ pageIndex:Int) {
        Events.pageDisappeared(pageNum:pageIndex+1).trackEvent()
    }

    
    func triggerEvent_PageSpreadChanged(_ oldPageIndexes:IndexSet, newPageIndexes:IndexSet) {
        let newPageNums:[Int] = newPageIndexes.map { (pageIndex) -> Int in
            return pageIndex + 1
        }
        
        let oldPageNums:[Int] = oldPageIndexes.map { (pageIndex) -> Int in
            return pageIndex + 1
        }
        
        Events.pageSpreadChanged(newPageNums: newPageNums, oldPageNums: oldPageNums).trackEvent()
    }
    
    
    func triggerEvent_PageSpreadZoomedIn(_ pageIndexes:IndexSet) {
        let pageNums:[Int] = pageIndexes.map { (pageIndex) -> Int in
            return pageIndex + 1
        }
        Events.pageSpreadZoomedIn(pageNums: pageNums).trackEvent()
    }
    func triggerEvent_PageSpreadZoomedOut(_ pageIndexes:IndexSet) {
        let pageNums:[Int] = pageIndexes.map { (pageIndex) -> Int in
            return pageIndex + 1
        }
        Events.pageSpreadZoomedOut(pageNums: pageNums).trackEvent()
    }
    
    
    func triggerEvent_PageTapped(_ pageIndex:Int, location:CGPoint) {
        Events.pageTapped(pageNum: pageIndex+1, location: location).trackEvent()
    }
    func triggerEvent_PageDoubleTapped(_ pageIndex:Int, location:CGPoint) {
        // TODO: not triggered yet
        Events.pageDoubleTapped(pageNum: pageIndex+1, location: location).trackEvent()
    }
    func triggerEvent_PageLongPressed(_ pageIndex:Int, location:CGPoint) {
        Events.pageLongPressed(pageNum: pageIndex+1, location: location).trackEvent()
    }
}
