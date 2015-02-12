//
//  ETA_CatalogReaderPageStatisticEvent.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_CatalogReaderPageStatisticEvent.h"

#import "ETA_Log.h"

@interface ETA_CatalogReaderPageStatisticEvent ()

@property (nonatomic, assign) NSTimeInterval currentRunStartTimestamp;
@property (nonatomic, assign) NSTimeInterval previousRunsDuration; // updated when paused

@end

@implementation ETA_CatalogReaderPageStatisticEvent : NSObject

- (instancetype) init
{
    NSAssert(NO, NSLocalizedString(@"Page Statistic Event must be init'd with valid type, orientation, pageRange, and viewSessionID", nil));
    return nil;
}

- (instancetype) initWithType:(ETA_CatalogReaderPageStatisticEventType)type orientation:(ETA_CatalogReaderPageStatisticEventOrientation)orientation pageRange:(NSRange)pageRange viewSessionID:(NSString*)viewSessionID
{
    NSParameterAssert(viewSessionID);
    
    if (self = [super init])
    {
        _paused = YES;
        _type = type;
        _orientation = orientation;
        _pageRange = pageRange;
        _viewSessionID = viewSessionID;
        _previousRunsDuration = 0;
        _currentRunStartTimestamp = -1;
    }
    return self;
}

- (void) start
{
    @synchronized(self)
    {
        if (!self.isPaused)
            return;
        
        _currentRunStartTimestamp = [NSDate timeIntervalSinceReferenceDate];
        _paused = NO;
        
        ETASDKLogInfo(@"STARTING: %@", self.debugDescription);
    }
}
- (void) pause
{
    @synchronized(self)
    {
        if (self.isPaused)
            return;
        
        _previousRunsDuration += ([NSDate timeIntervalSinceReferenceDate]-_currentRunStartTimestamp);
        
        ETASDKLogInfo(@"PAUSE: %@", self.debugDescription);
        
        _paused = YES;
    }
}

- (NSTimeInterval) totalRunTime
{
    @synchronized(self)
    {        
        NSTimeInterval totalRunTime = _previousRunsDuration;
        if (!self.isPaused)
        {
            totalRunTime += ([NSDate timeIntervalSinceReferenceDate]-_currentRunStartTimestamp);
        }
        return totalRunTime;
    }
}


- (NSDictionary*) toDictionary
{
    return @{
             @"type": [self _stringForType:self.type],
             @"orientation": [self _stringForOrientation:self.orientation],
             @"ms": @(round([self totalRunTime] * 1000.0)),
             @"pages": [self _stringForPageRange:self.pageRange],
             @"view_session": self.viewSessionID,
             };
}

- (NSString*) description
{
    NSDictionary* dict = self.toDictionary;
    //<CatalogReaderPageStatisticEvent: 0x7fe960588a70; view | portait | pages: 1,3 | runtime: 1.546s (paused) | ABCD1235ACD>
    return [NSString stringWithFormat:@"<%@: %p; %@ | %@ | pages: %@ | runtime: %.3fs (%@) | %@>", NSStringFromClass(self.class), self, dict[@"type"], dict[@"orientation"], dict[@"pages"], [self totalRunTime], self.isPaused ? @"paused": @"active", self.viewSessionID];
}


- (NSString*) _stringForType:(ETA_CatalogReaderPageStatisticEventType)type
{
    switch (type) {
        case ETA_CatalogReaderPageStatisticEventType_View:
            return @"view";
        case ETA_CatalogReaderPageStatisticEventType_Zoom:
            return @"zoom";
    }
}

- (NSString*) _stringForOrientation:(ETA_CatalogReaderPageStatisticEventOrientation)orientation
{
    switch (orientation) {
        case ETA_CatalogReaderPageStatisticEventOrientation_Portrait:
            return @"portrait";
        case ETA_CatalogReaderPageStatisticEventOrientation_Landscape:
            return @"landscape";
    }
}

- (NSString*) _stringForPageRange:(NSRange)pageRange
{
    if (pageRange.length == 0)
        return @"0";
    
    NSMutableArray* pages = [NSMutableArray array];

    for (NSUInteger i = pageRange.location; i < pageRange.location + pageRange.length; i++)
    {
        [pages addObject:@(i)];
    }
    
    return [pages componentsJoinedByString:@","];
}

@end

