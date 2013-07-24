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
#import "ETA_PageFlip.h"
#import "ETA_ShoppingListManager.h"
#import "ETA_ShoppingList.h"

@interface ETAExampleViewController ()

@property (nonatomic, readwrite, strong) ETA* eta;
@property (nonatomic, readwrite, strong) ETA_ShoppingListManager* shoppingListManager;
@property (nonatomic, readwrite, strong) ETA_PageFlip* webview;
@end

@implementation ETAExampleViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        
    }
    return self;
}

- (void) dealloc
{
    [self.shoppingListManager removeObserver:self forKeyPath:@"shoppingLists"];
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.eta = [ETA etaWithAPIKey:ETA_APIKey apiSecret:ETA_APISecret];
    
    [self.eta setLatitude:55.40227410 longitude:12.1873010 distance:5000 isFromSensor:NO];
    
    self.shoppingListManager = [ETA_ShoppingListManager managerWithETA:self.eta];
    self.shoppingListManager.pollRate = ETA_ShoppingListManager_PollRate_Default;
    

    [[NSNotificationCenter defaultCenter] addObserverForName:ETA_ShoppingListManager_ListsChangedNotification
                                                      object:self.shoppingListManager
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      DLog(@"Lists Modified: %@", note.userInfo);
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:ETA_ShoppingListManager_ItemsChangedNotification
                                                      object:self.shoppingListManager
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      DLog(@"Items Modified: %@", note.userInfo);
                                                  }];
    
    
    [[NSNotificationCenter defaultCenter] addObserverForName:ETA_SessionUserIDChangedNotification
                                                      object:self.eta
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      [self updateUserIDLabel];
                                                  }];
    
    
//    
//    [eta api:@"/v2/catalogs?catalog_ids=15,12"
//        type:ETARequestTypeGET
//  parameters:nil
//  completion:^(id response, NSError *error, BOOL fromCache) {
//      DLog(@"%@, %@, %@", response, error, @(fromCache));
//  }];
//    
//    return;
////    [eta attachUserEmail:userEmail password:userPassword completion:^(NSError *error) {
////        DLog(@"userAttached");
////    }];
////    
//    for (NSUInteger i = 0; i<10; i++)
//    {
//        DLog(@"Start request %d", i);
//        [eta api:[NSString stringWithFormat:@"%d", i]
//               type:ETARequestTypeGET
//         parameters:nil
//         completion:^(NSDictionary *response, NSError *error, BOOL fromCache) {
//             DLog(@"Request %d", i);
//         }];
//    }
//    return;
//    return;
    
    DLog(@"[CONNECTING] STARTED...");
    [self.eta connect:^(NSError *error) {
        if (!error)
        {
            DLog(@"[CONNECTING] ...FINISHED - connected!");
            
            [self connectUser:nil];
        }
        else
        {
            DLog(@"[CONNECTING] ...FINISHED - not connected");
        }
    }];
    
//    
//    [self.eta connectWithUserEmail:userEmail
//                          password:userPassword
//                        completion:^(BOOL connected, NSError* error)
//    {
//        if (!connected)
//        {
//            DLog(@"[CONNECTING] ...FINISHED - not connected");
//        }
//        else if (error)
//        {
//            DLog(@"[CONNECTING] ...FINISHED - couldnt sign in");
//        }
//        else
//        {
//            DLog(@"[CONNECTING] ...FINISHED - signed in!");
//        }
//        
//        [self updateUserIDLabel];
//        
//    }];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


- (IBAction)addList:(id)sender
{
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    [df setTimeStyle:NSDateFormatterLongStyle];
    [df setDateStyle:NSDateFormatterShortStyle];
    NSString* name = [NSString stringWithFormat:@"test %@", [df stringFromDate:[NSDate date]]];
    [self.shoppingListManager createShoppingList:name];
}
- (IBAction)deleteList:(id)sender
{
    NSArray* shoppingLists = [self.shoppingListManager getAllShoppingLists];
    
    [self.shoppingListManager removeShoppingList:shoppingLists.firstObject];
}

- (IBAction)disconnectUser:(id)sender
{
    [self.eta detachUserWithCompletion:nil];
}
- (IBAction)connectUser:(id)sender
{
    NSString* userEmail = @"lh@etilbudsavis.dk";
    NSString* userPassword = @"lhlhlh";
    
    [self.eta attachUserEmail:userEmail password:userPassword completion:nil];
}




- (void) updateUserIDLabel
{
    NSString* userID = [self.eta attachedUserID];
    self.userIDLabel.text = (userID) ?: @"Disconnected";
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)etaWebViewDidStartLoad:(UIWebView *)webView
{
//    DLog(@"Did Start Load: %@", webView);
}
- (void)etaWebViewDidFinishLoad:(UIWebView *)webView
{
//    DLog(@"Did Finish Load: %@", webView);
}
- (void)etaWebView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    DLog(@"Did Fail Load: %@ %@", webView, error);
}

- (void)etaWebView:(UIWebView *)webView triggeredEventWithClass:(NSString *)eventClass type:(NSString *)type dataDictionary:(NSDictionary *)dataDictionary
{
//    DLog(@"triggeredEvent: '%@' '%@' %@", eventClass, type, dataDictionary);
}
- (void)etaWebView:(UIWebView*)webview proxyReadyEvent:(NSDictionary*)data
{
    [self.webview showCatalogView:@"f4e4uHg" parameters:@{@"headless":@YES}];
}

- (void) etaWebView:(UIWebView *)webview catalogViewSingleTapEvent:(NSDictionary *)data
{
    [self connectUser:nil];
}
@end
