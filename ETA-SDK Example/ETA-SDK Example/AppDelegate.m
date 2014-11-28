//
//  AppDelegate.m
//  ETA-SDK Example
//
//  Created by Laurie Hufford on 27/11/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "AppDelegate.h"

#import <ETA-SDK/ETA.h>

#import "ETA_APIKeyAndSecret.h"

// CocoaLumberjack Loggers
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDTTYLogger.h>


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self _initializeLogging];
    
    [self _initializeETASDK];

    // Override point for customization after application launch.
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - Initalization

- (void) _initializeETASDK
{
    // First thing you must do is initialize the SDK with your API key and secret (see ETA_APIKeyAndSecret.h)
    // You must also include the app version, as specified by your bundle
    // Once you call this initialize method, ETA.SDK will return a valid object.
    NSString* appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    [ETA initializeSDKWithAPIKey:ETA_APIKey
                       apiSecret:ETA_APISecret
                      appVersion:appVersion];

    // Always keep the location of the SDK up to date.
    // In this case we are hard-coding it, but in your app you should use the CLLocationManager
    [ETA.SDK setLatitude:55.631360 longitude:12.576595 radius:50000 isFromSensor:NO];
    
    // this will try to log in with the Dummy user email and password. You should ask your user for these values.
    [ETA.SDK attachUserEmail:ETA_DummyUserEmail password:ETA_DummyUserPassword completion:^(NSError *error) {
        if (error)
            DDLogError(@"Couldn't log user in");
        else
            DDLogInfo(@"User Logged In: %@", ETA.SDK.attachedUser);
    }];
}

- (void) _initializeLogging
{
    // We are using CocoaLumberjack for logging: https://github.com/CocoaLumberjack/CocoaLumberjack
    // You need to add Loggers that will receive the logs from ETA-SDK (and your own app if you want to use CocoaLumberjack)
    
    
    // Set the logging level for the SDK - it defaults to ETASDK_LogLevel_Error (which is reserved for serious issues).
    // This is independant from the logging level you set in your app - this is defined in the .pch file
    [ETA setLogLevel:ETASDK_LogLevel_Warn];
    
    // Choose where you wish to send your logs.
    // Here we are sending to Apple System log and Xcode console
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    // see https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/XcodeColors
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
}

@end
