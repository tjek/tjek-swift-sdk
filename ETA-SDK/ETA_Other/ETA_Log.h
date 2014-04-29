//
//  ETA_Log.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 28/04/14.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "DDLog.h"

#define ETASDK_LOG_CONTEXT 1983


typedef NS_OPTIONS(NSUInteger, ETASDK_LogFlag) {
    ETASDK_LogFlag_Error    = 1 << 0,
    ETASDK_LogFlag_Warn     = 1 << 1,
    ETASDK_LogFlag_Info     = 1 << 2,
    ETASDK_LogFlag_Debug    = 1 << 3,
};

typedef NS_ENUM(NSUInteger, ETASDK_LogLevel) {
    ETASDK_LogLevel_Off = 0,                                                // No Logging
    ETASDK_LogLevel_Error = (ETASDK_LogLevel_Off | ETASDK_LogFlag_Error),   // Only for non-recoverable issues
    ETASDK_LogLevel_Warn = (ETASDK_LogLevel_Error | ETASDK_LogFlag_Warn),   // If we get an issue, but are able to continue
    ETASDK_LogLevel_Info = (ETASDK_LogLevel_Warn | ETASDK_LogFlag_Info),    // Non-critical information
    ETASDK_LogLevel_Debug = (ETASDK_LogLevel_Info | ETASDK_LogFlag_Debug),  // Very verbose - includes performance timings
};


BOOL ETASDK_IsLogLevel(ETASDK_LogLevel logLevel);
void ETASDK_SetLogLevel(ETASDK_LogLevel logLevel);
ETASDK_LogLevel ETASDK_GetLogLevel();


#define ETASDKLogError(frmt, ...)     SYNC_LOG_OBJC_MAYBE(ETASDK_GetLogLevel(), ETASDK_LogFlag_Error,   ETASDK_LOG_CONTEXT, frmt, ##__VA_ARGS__)
#define ETASDKLogWarn(frmt, ...)     ASYNC_LOG_OBJC_MAYBE(ETASDK_GetLogLevel(), ETASDK_LogFlag_Warn,    ETASDK_LOG_CONTEXT, frmt, ##__VA_ARGS__)
#define ETASDKLogInfo(frmt, ...)     ASYNC_LOG_OBJC_MAYBE(ETASDK_GetLogLevel(), ETASDK_LogFlag_Info,    ETASDK_LOG_CONTEXT, frmt, ##__VA_ARGS__)
#define ETASDKLogDebug(frmt, ...)    ASYNC_LOG_OBJC_MAYBE(ETASDK_GetLogLevel(), ETASDK_LogFlag_Debug,   ETASDK_LOG_CONTEXT, frmt, ##__VA_ARGS__)

