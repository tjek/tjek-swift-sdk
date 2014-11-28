//
//  ETA_Log.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 28/04/14.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ETA_Log.h"

static ETASDK_LogLevel etaLogLevel = ETASDK_LogLevel_Error;

void ETASDK_SetLogLevel(ETASDK_LogLevel logLevel)
{
    etaLogLevel = logLevel;
}

ETASDK_LogLevel ETASDK_GetLogLevel ()
{
    return etaLogLevel;
}

BOOL ETASDK_IsLogLevel(ETASDK_LogLevel logLevel)
{
    return (ETASDK_GetLogLevel() & logLevel);
}