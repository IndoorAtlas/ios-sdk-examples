/**
 * IndoorAtlas SDK positioning example
 * Prints the received locations to debug console
 */

#import <IndoorAtlas/IALocationManager.h>
#import "ConsoleViewController.h"
#import "../ApiKeys.h"

@interface ConsoleViewController () <IALocationManagerDelegate>
@property (nonatomic, strong) IALocationManager *manager;
@end

@implementation ConsoleViewController

#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;
    CLLocation *l = [(IALocation*)locations.lastObject location];

    // The accuracy of coordinate position depends on the placement of floor plan image.
    NSLog(@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude);
}

#pragma mark IndoorAtlas API Usage

/**
 * Authenticate to IndoorAtlas services and request location updates
 */
- (void)requestLocation
{
    // Create IALocationManager and point delegate to receiver
    self.manager = [IALocationManager sharedInstance];
    self.manager.delegate = self;

    // Optionally initial location
    IALocation *location = [IALocation locationWithFloorPlanId:kFloorplanId];
    self.manager.location = location;

    // Request location updates
    [self.manager startUpdatingLocation];
}

#pragma mark boilerplate
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self requestLocation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
}

@end
