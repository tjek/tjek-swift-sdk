//
//  ETA_DBSyncModelObject.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ModelObject.h"

typedef enum {
    ETA_DBSyncState_ToBeSynced      = 0, // the object has been created/modified, but not yet (successfully) synced with the server
    ETA_DBSyncState_Syncing         = 1, // the object is in the process of being synced to the server
    ETA_DBSyncState_Synced          = 2, // the object was successfully synced to the server
    
    ETA_DBSyncState_ToBeDeleted     = 3, // the object needs to be deleted from the server
    ETA_DBSyncState_Deleting        = 4, // the object is in the process of being deleted from the server
    ETA_DBSyncState_Deleted         = 5, // the object was successfully deleted to the server    
} ETA_DBSyncState;

// These are ETA_ModelObjects that can be synced to a DB
@interface ETA_DBSyncModelObject : ETA_ModelObject

@property (nonatomic, readwrite, assign) ETA_DBSyncState state;
@property (nonatomic, readwrite, copy) NSString* syncUserID;

@end
