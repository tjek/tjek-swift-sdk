//
//  ETA_CatalogReaderPageStatisticEvent.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 25/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    ETA_CatalogReaderPageStatisticEventType_View,
    ETA_CatalogReaderPageStatisticEventType_Zoom,
} ETA_CatalogReaderPageStatisticEventType;

typedef enum : NSUInteger {
    ETA_CatalogReaderPageStatisticEventOrientation_Landscape,
    ETA_CatalogReaderPageStatisticEventOrientation_Portrait,
} ETA_CatalogReaderPageStatisticEventOrientation;



@interface ETA_CatalogReaderPageStatisticEvent : NSObject


- (instancetype) initWithType:(ETA_CatalogReaderPageStatisticEventType)type orientation:(ETA_CatalogReaderPageStatisticEventOrientation)orientation pageRange:(NSRange)pageRange viewSessionID:(NSString*)viewSessionID;

@property (nonatomic, assign, readonly) ETA_CatalogReaderPageStatisticEventType type;
@property (nonatomic, assign, readonly) ETA_CatalogReaderPageStatisticEventOrientation orientation;
@property (nonatomic, assign, readonly) NSRange pageRange;
@property (nonatomic, strong, readonly) NSString* viewSessionID;

@property (nonatomic, assign, readonly, getter=isPaused) BOOL paused;


- (void) start;
- (void) pause;
- (NSTimeInterval) totalRunTime;

- (NSDictionary*) toDictionary;

@end

