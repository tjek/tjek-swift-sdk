//
//  CatalogsListViewController.m
//  ETA-SDK Example
//
//  Created by Laurie Hufford on 7/29/13.
//  Copyright (c) 2013 eTilbudsavis. All rights reserved.
//

#import "CatalogsListViewController.h"

// Model
#import <ETA-SDK/ETA.h>
#import <ETA-SDK/ETA_Catalog.h>

// View Controllers
#import "CatalogReaderViewController.h"

// Utilities
#import <AFNetworking/UIImageView+AFNetworking.h>


@interface CatalogsListViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, readwrite, strong) NSMutableArray* catalogs;

@end

@implementation CatalogsListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Catalogs",@"Catalogs title");
    
    self.catalogs = nil;
    
    // start the spinner spinning
    self.activitySpinner.color = [UIColor blackColor];
    [self.activitySpinner startAnimating];
    
    // start looking for catalogs
    [self refreshCatalogs];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = nil;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}


// This method will send a request to the SDK, asking for a list of ETA_Catalogs
// Note that before any API requests you must have first called +initializeSDKWithAPIKey:apiSecret: (see AppDelegate)
- (void) refreshCatalogs
{
    DDLogInfo(@"Refreshing Catalogs list...");
    
    // We are using the ETA_API object to get the api path for a specific endpoint -
    //   this makes handling the URLs a lot easier and future proof
    // We are also sending 2 order-by parameters: distance and name -
    //   the results will be sorted first by the distance from the location we set in the AppDelegate,
    //   and then by the name of the catalog.
    [ETA.SDK api:[ETA_API path:ETA_API.catalogs]
            type:ETARequestTypeGET
      parameters:@{@"order_by": @[@"distance", @"name"]}
      completion:^(NSArray* jsonCatalogs, NSError *error, BOOL fromCache) {
          // The completion handler is called on the main thread and returns a JSON response -
          //   this can be in NSArray, NSDictionary, NSString or NSNumber.
          
          // Ignore results that come from the cache - a server result will arrive shortly.
          // You can also explicitly ignore cached results by using a different -api:... method
          if (fromCache)
              return;
          
          
          // Something went wrong if the `error` object is not nil
          if (error)
          {
              DDLogError(@"Could not refresh: %@ (%@)", error.userInfo[NSLocalizedDescriptionKey], @(error.code));
              return;
          }
          
          // As we are asking for a list of catalogs we can assume the result is an array.
          // If not then something went wrong.
          if (![jsonCatalogs isKindOfClass:[NSArray class]])
          {
              DDLogError(@"Could not refresh: Invalid response format");
              return;
          }

          
          
          // loop through all the json dictionaries that the SDK sent us
          // for each one, convert it into an ETA_Catalog object.
          // this parses a lot of the JSON strings into useful objects, and makes your life a lot easier
          NSMutableArray* catalogs = [NSMutableArray arrayWithCapacity:jsonCatalogs.count];
          for (NSDictionary* catalogDict in jsonCatalogs)
          {
              ETA_Catalog* catalog = [[ETA_Catalog objectFromJSONDictionary:catalogDict] copy];
              if (catalog)
                  [catalogs addObject:catalog];
          }
          
          // save the resulting data
          self.catalogs = catalogs;
          
          // update the tableview and spinner
          [self.activitySpinner stopAnimating];
          [self.tableView reloadData];
          
          DDLogInfo(@"...Catalogs list refreshed");
      }];
}



#pragma mark - TableView Datasource

// The dateformatter for pretty-printing the catalog's date
- (NSDateFormatter*)tableViewDateFormatter
{
    static NSDateFormatter* df = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [[NSDateFormatter alloc] init];
        df.dateStyle = NSDateFormatterShortStyle;
        df.timeStyle = NSDateFormatterNoStyle;
    });
    return df;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // see storyboard for prototype
    NSString* cellIdentifier = @"ETACatalogCellIdentifier";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    
    // get the catalog we want to update the cell for
    ETA_Catalog* catalog = self.catalogs[indexPath.row];
    
    
    // get the brand color of the catalog.
    // if the brand color is white, make it grey (so we can see it against the white bg)
    UIColor* brandColor = (catalog.branding.pageflipColor) ?: catalog.branding.color;
    if ([brandColor isEqual:[UIColor colorWithRed:1 green:1 blue:1 alpha:1]])
        brandColor = [UIColor grayColor];
    
    
    // update the cell's text label properties
    // the text is the name of the catalog's dealer from the branding object
    cell.textLabel.text = catalog.branding.name;
    cell.textLabel.textColor = brandColor;
    
    // use the catalog's run dates in the cell's detail label
    NSDateFormatter* df = [self tableViewDateFormatter];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", [df stringFromDate:catalog.runFromDate],[df stringFromDate:catalog.runTillDate]];
    
    // we are using the catalog's thumbnail image url as the imageView
    // here we are using an AFNetworking (included) UIImageView category
    // until it loads, it will use the placeholderImage
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    cell.imageView.clipsToBounds = YES;
    [cell.imageView setImageWithURL:[catalog imageURLForSize:ETA_Catalog_ImageSize_Thumb]
                   placeholderImage:[UIImage imageNamed:@"CatalogsList-ThumbPlaceholder"]];
    
    // when the cell is selected it will highlight to be the brand color
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = [brandColor colorWithAlphaComponent:0.2];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.catalogs.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    
    [self performSegueWithIdentifier:@"CatalogReaderViewSegue" sender:indexPath];
}


// This method is called before we transition to the CatalogView viewcontroller
// The segue source and its ID are defined in the storyboard
// Here we want to give the CatalogView catalog we want to see
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(NSIndexPath*)indexPath
{
    if (!indexPath)
        return;
    
    // get the catalog object that was selected
    ETA_Catalog* catalog = self.catalogs[indexPath.row];
    
    if ([segue.identifier isEqualToString:@"CatalogReaderViewSegue"])
    {
        // get the destination view controller from the storyboard
        CatalogReaderViewController* catalogReaderVC = (CatalogReaderViewController*)segue.destinationViewController;
        [catalogReaderVC setCatalogID:catalog.uuid title:catalog.branding.name brandColor:(catalog.branding.pageflipColor) ?: catalog.branding.color];
    }
}

@end
