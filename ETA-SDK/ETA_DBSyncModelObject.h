//
//  ETA_DBSyncModelObject.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_ModelObject.h"

typedef enum {
    ETA_DBSyncState_ToBeAdded       = 0, // the object has been created but not yet (successfully) added to the server
    ETA_DBSyncState_Adding          = 1, // the object is in the process of being synced to the server
    ETA_DBSyncState_Added           = 2, // the object was successfully synced to the server
    
    ETA_DBSyncState_ToBeDeleted     = 3, //
    ETA_DBSyncState_Deleting        = 4, // the object is in the process of being deleted from the server
    ETA_DBSyncState_Deleted         = 5, // the object was successfully deleted to the server
    
    ETA_DBSyncState_Offline         = 6, //
    ETA_DBSyncState_Error           = 7, //
} ETA_DBSyncState;

// These are ETA_ModelObjects that can be synced to a DB
@interface ETA_DBSyncModelObject : ETA_ModelObject

@property (nonatomic, readwrite, assign) ETA_DBSyncState state;

@end
