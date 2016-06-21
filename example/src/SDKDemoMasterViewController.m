#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "SDKDemoMasterViewController.h"
#import "SDKDemoAppDelegate.h"
#import "Examples/Examples.h"

@implementation SDKDemoMasterViewController {
    NSArray *demos_;
    NSArray *demoSections_;
    UIPopoverController *popover_;
    UIBarButtonItem *samplesButton_;
    __weak UIViewController *controller_;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *backButton =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back")
                                     style:UIBarButtonItemStylePlain
                                    target:nil
                                    action:nil];
    [self.navigationItem setBackBarButtonItem:backButton];

    self.title = NSLocalizedString(@"IndoorAtlas SDK Demos", @"IndoorAtlas SDK Demos");

    self.tableView.autoresizingMask =
    UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    demoSections_ = [Examples loadSections];
    demos_ = [Examples loadDemos];
}

#pragma mark - UITableViewController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return demoSections_.count;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
    return 35.0;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    return [demoSections_ objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return [[demos_ objectAtIndex: section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell =
    [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellIdentifier];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }

    NSDictionary *demo = [[demos_ objectAtIndex:indexPath.section]
                          objectAtIndex:indexPath.row];
    cell.textLabel.text = [demo objectForKey:@"title"];
    cell.detailTextLabel.text = [demo objectForKey:@"description"];

    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // The user has chosen a sample; load it and clear the selection!
    [self loadDemo:indexPath.section atIndex:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Private methods

- (void)loadDemo:(NSUInteger)section
         atIndex:(NSUInteger)index {
    NSDictionary *demo = [[demos_ objectAtIndex:section] objectAtIndex:index];
    UIViewController *controller =
    [[[demo objectForKey:@"controller"] alloc] init];
    controller_ = controller;

    if (controller != nil) {
        controller.title = [demo objectForKey:@"title"];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

@end
