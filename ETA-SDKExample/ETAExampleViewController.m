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
    [eta connect:^(NSError* error) {
        if (!error)
        {
            DLog(@"Connected!");
        }
        else
        {
            DLog(@"Could not connect %@", error);
        }
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
