//
//  ViewController.m
//  Test
//
//  Created by Rasmus Hummelmose on 03/07/12.
//  Copyright (c) 2012 Tapp ApS. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>

@interface ViewController () <ETADelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) ETA *eta;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *location;

@end

@implementation ViewController

@synthesize eta = _eta;
@synthesize webView = _webView;
@synthesize locationManager = _locationManager;
@synthesize location = _location;

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    // We instantiate ETA and set its delegate
    self.eta = [ETA etaWithAPIKey:@"c4907807193cd4f6465abf872a2a72be" apiSecret:@"1aeecf1867d71453ee75f329aee38013"];
    self.eta.delegate = self;
    
    //[self.eta performAPIRequestWithPathString:<#(NSString *)#> requestType:<#(ETARequestType)#> optionsDictionary:<#(NSDictionary *)#>]

    // We instantiate a CLLocationManager, set its delegate and start monitoring location changes
    self.locationManager.delegate = self;
    [self.locationManager startMonitoringSignificantLocationChanges];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


#pragma mark - Initializers

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return _locationManager;
}


#pragma mark - CoreLocation Delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    // We dissect the location object for use with ETA
    self.location = newLocation;
    float accuracy = self.location.horizontalAccuracy;
    float latitude = self.location.coordinate.latitude;
    float longitude = self.location.coordinate.longitude;
    int locationDetermined = [[NSDate date] timeIntervalSince1970];
    
    int distance = 1000; // we want results from within 1km
    
    // We save the collected location in the ETA instance
    [self.eta setLocationWithAccuracy:accuracy latitude:latitude longitude:longitude locationDetermined:locationDetermined distance:distance];
    
    // Now that we have the location set, we instantiate a UIWebView prepared for the ETA viewer
    self.webView = [self.eta webViewForETA];
}


#pragma mark - ETA Delegate

- (void)etaRequestSucceededAndReturnedDictionary:(NSDictionary *)dictionary
{
    NSLog(@"[ETA Delegate] Request succeeded with dictionary: %@", dictionary);
}

- (void)etaRequestFailedWithError:(NSString *)error
{
    NSLog(@"[ETA Delegate] Request failed with error: %@", error);
}

- (void)etaWebViewLoaded:(UIWebView *)webView
{
    NSLog(@"[ETA Delegate] WebView for ETA loaded: %@", webView);
    
    // As the UIWebView has now loaded and ETA has been initiated, we can call
    // pageflip functions and deploy the UIWebView to the VC's view
    [self.eta pageflipWithCatalog:@"71ffHDg" page:1];
    self.view = webView;
}

- (void)etaWebViewFailedToLoadWithError:(NSString *)error
{
    NSLog(@"[ETA Delegate] An error occured while loading web view: %@", error);
}

- (void)etaWebView:(UIWebView *)webView triggeredEventWithClass:(NSString *)class type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary
{
    NSLog(@"[ETA Delegate] Received event with class: %@, %@, %@", class, type, dataDictionary);
}


@end
