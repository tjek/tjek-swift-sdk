//
//  ETA_ShoppingListItem.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETA_DBSyncModelObject.h"

@interface ETA_ShoppingListItem : ETA_DBSyncModelObject

@property (nonatomic, readwrite, strong) NSDate* modified;
@property (nonatomic, readwrite, strong) NSString* name; // actually 'description', but that's a special case in cocoa
@property (nonatomic, readwrite, assign) NSInteger count;
@property (nonatomic, readwrite, assign) BOOL tick;
@property (nonatomic, readwrite, strong) NSString* offerID;
@property (nonatomic, readwrite, strong) NSString* creator;
@property (nonatomic, readwrite, strong) NSString* shoppingListID;

//// uuid and description are required
//// if modified is nil, current date is used
//+ (instancetype) shoppingListItemWithUUID:(NSString*)uuid
//                              description:(NSString*)name
//                                    count:(NSInteger)count
//                                   ticked:(BOOL)ticked
//                                  offerID:(NSString*)offerID
//                           shoppingListID:(NSString*)shoppingListID
//                                  creator:(NSString*)creator
//                             modifiedDate:(NSDate*)modified;


@end
