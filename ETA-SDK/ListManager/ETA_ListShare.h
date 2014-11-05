//
//  ETA_ListShare.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/10/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_DBSyncModelObject.h"

typedef enum {
    ETA_ListShare_Access_None = 0,
    ETA_ListShare_Access_ReadOnly = 1,
    ETA_ListShare_Access_ReadWrite = 2,
    ETA_ListShare_Access_Owner = 3,
} ETA_ListShare_Access;

@interface ETA_ListShare : ETA_DBSyncModelObject

@property (nonatomic, strong) NSString* listUUID;
@property (nonatomic, strong) NSString* userEmail;
@property (nonatomic, strong) NSString* userName;
@property (nonatomic, assign) ETA_ListShare_Access access;
@property (nonatomic, assign) BOOL accepted;
@property (nonatomic, strong) NSString* acceptURL;

+ (ETA_ListShare_Access) accessForString:(NSString*)shareAccessString;
+ (NSString*) stringForAccess:(ETA_ListShare_Access)shareAccess;


@end
