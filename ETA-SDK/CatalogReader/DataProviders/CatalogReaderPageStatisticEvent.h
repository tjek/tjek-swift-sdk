//
//  CatalogReaderDataCollector.h
//  NativeCatalogReader
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    CatalogReaderPageStatisticEventType_View,
    CatalogReaderPageStatisticEventType_Zoom,
} CatalogReaderPageStatisticEventType;

typedef enum : NSUInteger {
    CatalogReaderPageStatisticEventOrientation_Landscape,
    CatalogReaderPageStatisticEventOrientation_Portrait,
} CatalogReaderPageStatisticEventOrientation;



@interface CatalogReaderPageStatisticEvent : NSObject


- (instancetype) initWithType:(CatalogReaderPageStatisticEventType)type orientation:(CatalogReaderPageStatisticEventOrientation)orientation pageRange:(NSRange)pageRange viewSessionID:(NSString*)viewSessionID;

@property (nonatomic, assign, readonly) CatalogReaderPageStatisticEventType type;
@property (nonatomic, assign, readonly) CatalogReaderPageStatisticEventOrientation orientation;
@property (nonatomic, assign, readonly) NSRange pageRange;
@property (nonatomic, strong, readonly) NSString* viewSessionID;

@property (nonatomic, assign, readonly, getter=isPaused) BOOL paused;


- (void) start;
- (void) pause;
- (NSTimeInterval) totalRunTime;

- (NSDictionary*) toDictionary;

@end



@protocol CatalogReaderPageStatisticCollectorProtocol <NSObject>

- (void) collectPageStatisticsEvent:(CatalogReaderPageStatisticEvent*)statsEvent forCatalogID:(NSString*)catalogID;

@end
