/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <UIKit/UIKit.h>

@class SDKDemoAppDelegate;

@interface SDKDemoMasterViewController : UITableViewController <
UITableViewDataSource,
UITableViewDelegate>

@property(nonatomic, assign) SDKDemoAppDelegate *appDelegate;

@end
