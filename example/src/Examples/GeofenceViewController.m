/**
 * IndoorAtlas SDK positioning example
 */

#import <IndoorAtlas/IALocationManager.h>
#import "GeofenceViewController.h"
#import "../ApiKeys.h"

@interface GeofenceViewController () <IALocationManagerDelegate>
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) UILabel *regionLabel;
@property (nonatomic, strong) NSString *geofenceStatus;
@property BOOL hasGeofence;

@property NSInteger floorLevel;
@property IACertainty floorCertainty;
@end

@implementation GeofenceViewController

#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;
    IALocation *ialoc = [locations lastObject];
    CLLocation *l = [ialoc location];
    
    // The accuracy of coordinate position depends on the placement of floor plan image.
    NSLog(@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude);
    
    // Register a new geofence once the position converges
    if (l.horizontalAccuracy < 10 && self.hasGeofence==NO) {
        
        const double lat_per_meter = 9e-06*cos(M_PI/180.0*l.coordinate.latitude);
        const double lon_per_meter = 9e-06;
        
        // Add a circular geofence by adding points with a 10 m radius clockwise
        NSMutableArray<NSNumber*> *edges = [NSMutableArray array];
        for (int i = 1; i <= 10; i++) {
            double lat = l.coordinate.latitude + 10*lat_per_meter*sin(-2*M_PI*i/10);
            double lon = l.coordinate.longitude + 10*lon_per_meter*cos(-2*M_PI*i/10);
            [edges addObject:[NSNumber numberWithDouble:lat]];
            [edges addObject:[NSNumber numberWithDouble:lon]];
        }
        IAGeofence *geo = [IAPolygonGeofence polygonGeofenceWithIdentifier:@"My geofence" andFloor:ialoc.floor edges:edges];
        
        [manager startMonitoringForGeofence:geo];
        
        self.hasGeofence = YES;
        self.geofenceStatus = @"Registered geofence with 10 m radius.";
        NSLog(@"New geofence registered.");
        
    }
    
    [self updateLabel];
}

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region
{
    if (region.type == kIARegionTypeGeofence) {
        self.geofenceStatus = @"Inside my geofence";
        NSLog(@"Inside geofence.");
    }
    [self updateLabel];
}

- (void)indoorLocationManager:(IALocationManager *)manager didExitRegion:(IARegion *)region
{
    if (region.type == kIARegionTypeGeofence) {
        self.geofenceStatus = @"Outside my geofence";
        NSLog(@"Outside geofence.");
    }
    [self updateLabel];
}

- (void)updateLabel
{
    
    NSString *status = @"Once the position estimate converges a geofence will be initialized to the current user location with a 10 m radius.";
    
    if (self.hasGeofence) {
      status = @"Walking back into the geofence will trigger an Enter event it and walking out from it will trigger an Exit event.";
    }
        
    NSString * htmlString = [NSString stringWithFormat:@"<div style=\"text-align:center\"><big><h1>Geofence</h1><br>%@<br><hr><b>Status:</b><br>%@</div></big>",status,self.geofenceStatus];
    
    NSAttributedString * attrStr = [[NSAttributedString alloc] initWithData:[htmlString dataUsingEncoding:NSUnicodeStringEncoding] options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType } documentAttributes:nil error:nil];
    
    [_regionLabel setAttributedText:attrStr];
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
    
    _regionLabel = [[UILabel alloc] initWithFrame:self.view.frame];
    
    [_regionLabel setTextColor:[UIColor blackColor]];
    [_regionLabel setBackgroundColor:[UIColor whiteColor]];
    [_regionLabel setFont:[UIFont fontWithName: @"Trebuchet MS" size: 14.0f]];
    
    [_regionLabel setNumberOfLines:0];
    [self updateLabel];
    
    [self.view addSubview:_regionLabel];

    self.geofenceStatus = @"Waiting for position to converge.";
    [self updateLabel];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
}

@end
