//
//  ETAExampleViewController.h
//  ETA-SDKExample
//
//  Created by Laurie Hufford on 7/8/13.
//  Copyright (c) 2013 eTilbudsAvis. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ETAExampleViewController : UIViewController

- (IBAction)addList:(id)sender;
- (IBAction)deleteList:(id)sender;

- (IBAction)disconnectUser:(id)sender;
- (IBAction)connectUser:(id)sender;
@property (nonatomic, readwrite, strong) IBOutlet UILabel* userIDLabel;

@end
