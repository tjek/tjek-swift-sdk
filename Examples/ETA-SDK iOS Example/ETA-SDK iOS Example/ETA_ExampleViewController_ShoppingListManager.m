//
//  ETA_ExampleViewController_ShoppingListManager.m
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 8/8/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ExampleViewController_ShoppingListManager.h"
#import "ETA_ShoppingListManager.h"
#import "ETA.h"

@interface ETA_ExampleViewController_ShoppingListManager ()

@end

@implementation ETA_ExampleViewController_ShoppingListManager

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shoppingListChangeNotification:) name:ETA_ShoppingListManager_ListsChangedNotification object:ETA_ShoppingListManager.sharedManager];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shoppingListItemChangeNotification:) name:ETA_ShoppingListManager_ItemsChangedNotification object:ETA_ShoppingListManager.sharedManager];
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    ETA_ShoppingListManager.sharedManager.verbose = YES;
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) shoppingListChangeNotification:(NSNotification*)notif
{
    NSLog(@"Lists Changed: %@", notif.userInfo);
}
- (void) shoppingListItemChangeNotification:(NSNotification*)notif
{
    NSLog(@"Items Changed: %@", notif.userInfo);
}

- (IBAction)addList:(id)sender
{
    ETA_ShoppingListManager* slm = [ETA_ShoppingListManager sharedManager];
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterShortStyle;
    df.timeStyle = NSDateFormatterLongStyle;
    
    NSString* name = [NSString stringWithFormat:@"Test List %@", [df stringFromDate:[NSDate date]]];
    [slm createShoppingList:name completion:^(ETA_ShoppingList *list, NSError *error, BOOL fromServer) {
        if (fromServer)
        {
            NSLog(@"Server Completed: %@ %@", list, error);
        }
        else
        {
            NSLog(@"Local Completed: %@ %@", list, error);
        }
    }];
}
@end
