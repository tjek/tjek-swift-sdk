//
//  ETA_ExampleViewController_Catalogs.m
//  ETA-SDK iOS Example
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "ETA_ExampleViewController_Catalogs.h"

#import <SDWebImage/UIImageView+WebCache.h>

#import "ETA.h"
#import "ETA_Catalog.h"

#import "ETA_ExampleViewController_CatalogView.h"

@interface ETA_ExampleViewController_Catalogs () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, readwrite, strong) NSMutableArray* catalogs;

@end

@implementation ETA_ExampleViewController_Catalogs

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Catalogs",@"Catalogs title");
    self.catalogs = nil;
    
    
	// Do any additional setup after loading the view.
    
    self.activitySpinner.color = [UIColor blackColor];
    [self.activitySpinner startAnimating];
    [self refreshCatalogs];
}

- (void) viewWillAppear:(BOOL)animated
{
    self.navigationController.navigationBar.tintColor = nil;
}

- (void) refreshCatalogs
{
    [ETA.SDK api:[ETA_API path:ETA_API.catalogs]
            type:ETARequestTypeGET
      parameters:@{@"order_by": @[@"distance", @"name"]}
      completion:^(NSArray* jsonCatalogs, NSError *error, BOOL fromCache) {
          if (error)
          {
              NSLog(@"Could not refresh: %@ (%d)", [ETA errorForCode:error.code], error.code);
              return;
          }
          if (fromCache)
              return;
          
          NSMutableArray* catalogs = [NSMutableArray arrayWithCapacity:jsonCatalogs.count];
          
          for (NSDictionary* catalogDict in jsonCatalogs)
          {
              ETA_Catalog* catalog = [[ETA_Catalog objectFromJSONDictionary:catalogDict] copy];
              if (catalog)
                  [catalogs addObject:catalog];
          }
          
          [self.activitySpinner stopAnimating];
          self.catalogs = catalogs;
          [self.tableView reloadData];
      }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [ETA.SDK clearCache];
}


- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // see storyboard for segue
    if ([segue.identifier isEqualToString:@"CatalogCellToCatalogViewSegue"])
    {
        ETA_ExampleViewController_CatalogView* catalogView = (ETA_ExampleViewController_CatalogView*)segue.destinationViewController;
        NSIndexPath* selectedIndexPath = [self.tableView indexPathForSelectedRow];
        if (selectedIndexPath)
        {
            ETA_Catalog* catalog = self.catalogs[selectedIndexPath.row];
            catalogView.catalog = catalog;
        }
    }
}

#pragma mark - TableView Datasource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // see storyboard for prototype
    NSString* cellIdentifier = @"ETACatalogCellIdentifier";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterShortStyle;
    df.timeStyle = NSDateFormatterNoStyle;

    
    ETA_Catalog* catalog = self.catalogs[indexPath.row];
    
    NSURL* thumbURL = [catalog imageURLForSize:ETA_Catalog_ImageSize_Thumb];
    NSString* brandName = catalog.branding.name;
    
    UIColor* brandColor = (catalog.branding.pageflipColor) ?: catalog.branding.color;
    
    // if the brand color is white, make it grey (so we can see it)
    if ([brandColor isEqual:[UIColor colorWithRed:1 green:1 blue:1 alpha:1]])
        brandColor = [UIColor grayColor];
    
    
    NSString* dateRangeStr = [NSString stringWithFormat:@"%@ - %@", [df stringFromDate:catalog.runFromDate],[df stringFromDate:catalog.runTillDate]];
    
    
    cell.textLabel.text = brandName;
    cell.textLabel.textColor = brandColor;
    cell.detailTextLabel.text = dateRangeStr;
    
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = brandColor;
    
    // using SDWebImage
    [cell.imageView setImageWithURL:thumbURL
                   placeholderImage:[UIImage imageNamed:@"catalogThumbPlaceholder.png"]];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.catalogs.count;
}

#pragma mark - TableView Delegate

- (void) viewDidAppear:(BOOL)animated
{
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}


@end
