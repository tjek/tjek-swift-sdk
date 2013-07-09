//
//  ETAExampleViewController.m
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import "ETAExampleViewController.h"

#import "ETA.h"
#import "ETA-APIKeyAndSecret.h"

@interface ETAExampleViewController ()

@end

@implementation ETAExampleViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    ETA* eta = [ETA etaWithAPIKey:ETA_APIKey apiSecret:ETA_APISecret];
    
    [eta connectWithUserEmail:@"lh@etilbudsavis.dk" password:@"" completion:^(BOOL connected, NSError* error)
    {
        if (!connected)
        {
            DLog(@"Could not connect %@", error);
        }
        else if (error)
        {
            DLog(@"Could not sign in %@", error);
        }
        else
        {
            DLog(@"Connected!");
            [eta makeRequest:@"/v2/catalogs"
                        type:ETARequestTypeGET
                  parameters:@{@"r_lat":@55.55, @"r_lng": @12.12, @"r_radius":@10000}
                  completion:^(NSDictionary *response, NSError *error) {
                      DLog(@"Request Response %@", response);
                  }];
        }
    }];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
