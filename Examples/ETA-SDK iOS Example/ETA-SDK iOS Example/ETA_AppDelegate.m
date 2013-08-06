//
//  ETA_AppDelegate.m
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/30/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_AppDelegate.h"

#import "ETA.h"
#import "ETA_APIKeyAndSecret.h"

@implementation ETA_AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // First thing you must do is initialize the SDK with your API key and secret (see ETA_APIKeyAndSecret.h)
    // Once you call this initialize method, ETA.SDK will return a valid object.
    [ETA initializeSDKWithAPIKey:ETA_APIKey apiSecret:ETA_APISecret];
    
    // Always keep the location of the SDK up to date.
    // In this case we are hard-coding it, but in your app you should use the CLLocationManager
    [ETA.SDK setLatitude:55.40227410 longitude:12.1873010 radius:50000 isFromSensor:NO];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
