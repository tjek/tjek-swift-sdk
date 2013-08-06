//
//  ETA_User.h
//  ETA-SDK
//
//  Created by Laurie Hufford on 7/17/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ModelObject.h"

typedef enum {
    ETA_UserGender_Male,
    ETA_UserGender_Female,
    ETA_UserGender_Unknown,
} ETA_UserGender;

@interface ETA_User : ETA_ModelObject

@property (nonatomic, strong) NSString* name;
@property (nonatomic, assign) ETA_UserGender gender;
@property (nonatomic, strong) NSString* birthYear;
@property (nonatomic, strong) NSString* email;
@property (nonatomic, strong) NSDictionary* permissions;


- (BOOL) allowsPermission:(NSString*)actionPermission;
@end
