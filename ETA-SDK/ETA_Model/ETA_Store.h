//
//  ETA_Store.h
//  Pods
//
//  Created by Laurie Hufford on 8/12/13.
//
//

#import "ETA_ModelObject.h"
#import "ETA_Branding.h"

#include <CoreLocation/CoreLocation.h>


@interface ETA_Store : ETA_ModelObject

@property (nonatomic, readwrite, strong) NSString* street;
@property (nonatomic, readwrite, strong) NSString* city;
@property (nonatomic, readwrite, strong) NSString* zipCode;
@property (nonatomic, readwrite, strong) NSDictionary* country;
@property (nonatomic, readwrite, assign) double latitude;
@property (nonatomic, readwrite, assign) double longitude;

@property (nonatomic, readwrite, strong) NSURL* dealerURL;
@property (nonatomic, readwrite, strong) NSString* dealerID;

@property (nonatomic, readwrite, strong) ETA_Branding* branding;
@property (nonatomic, readwrite, strong) NSString* contact;


- (CLLocationDistance) distanceFromLocation:(CLLocation*)location;

@end
