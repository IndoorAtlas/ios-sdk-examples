/**
 * IndoorAtlas SDK positioning example
 * Prints the received locations to debug console
 */

#import <IndoorAtlas/IALocationManager.h>
#import "ConsoleViewController.h"
#import "../ApiKeys.h"

@interface ConsoleViewController () <IALocationManagerDelegate>
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, assign) bool traced;
@end

@implementation ConsoleViewController

- (void)log:(NSString*)fmt, ...
{
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    self.textView.text = [NSString stringWithFormat:@"%@\n%@: %@", self.textView.text, [NSDate date], msg];
    NSLog(@"%@", msg);
}

#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;
    CLLocation *l = [(IALocation*)locations.lastObject location];

    if (!self.traced) {
        [self log:@"Trace ID: %@", [self.manager.extraInfo objectForKey:kIATraceId]];
        self.traced = true;
    }
    
    // The accuracy of coordinate position depends on the placement of floor plan image.
    [self log:@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude];
}

#pragma mark IndoorAtlas API Usage

/**
 * Authenticate to IndoorAtlas services and request location updates
 */
- (void)requestLocation
{
    self.traced = false;
    
    // Create IALocationManager and point delegate to receiver
    self.manager = [IALocationManager sharedInstance];
    self.manager.delegate = self;

    // Optionally initial location
    if (kFloorplanId.length) {
        IALocation *location = [IALocation locationWithFloorPlanId:kFloorplanId];
        self.manager.location = location;
        [self log:@"Give explicit location: %@", location];
    }

    // Request location updates
    [self.manager startUpdatingLocation];
}

#pragma mark boilerplate
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.textView = [UITextView new];
    self.textView.frame = self.view.bounds;
    self.textView.editable = NO;
    self.textView.scrollEnabled = YES;
    [self.view addSubview:self.textView];
    [self requestLocation];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.textView.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
    [self.textView removeFromSuperview];
    self.textView = nil;
}

@end
