/**
 * IndoorAtlas SDK iBeacons example
 * Inherited from AppleMapsOverlayViewController
 */

#import "BeaconsViewController.h"
#import "AppleMapsOverlayViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <MapKit/MapKit.h>
#import "../ApiKeys.h"

// Max distance from where the beacon is still detected
#define BeaconMaxDistance 10.0

@interface BeaconsViewController () <CLLocationManagerDelegate, MKMapViewDelegate>

@property CLLocationManager *mapLocationManager;
@property CLBeaconRegion *beaconRegion;
@property (nonatomic) BOOL beaconFound;

@end

@implementation BeaconsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (BeaconUUID.length == 0 || BeaconIdentifier.length == 0 || majorId.length == 0 || minorId.length == 0 || latitudeOfBeacon.length == 0 || longitudeOfBeacon.length == 0) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"iBeacon information not set"
                                                        message:@"Set iBeacon information in ApiKeys.h"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        UINavigationController *navigationController = self.navigationController;
        [navigationController popViewControllerAnimated:YES];
    }
    else {
        // Start all the necessary tasks to monitor and range beacons
        self.beaconFound = NO;
        self.mapLocationManager = [[CLLocationManager alloc] init];
        self.mapLocationManager.delegate = self;
        
        NSUUID *UUID = [[NSUUID alloc] initWithUUIDString:BeaconUUID];
        [self registerBeaconRegionWithUUID:UUID andIdentifier:BeaconIdentifier];
    }
}

// Register beacon region
- (void)registerBeaconRegionWithUUID:(NSUUID *)proximityUUID andIdentifier:(NSString*)identifier {
    
    // Create the beacon region to be monitored.
    self.beaconRegion = [[CLBeaconRegion alloc]
                         initWithProximityUUID:proximityUUID
                         identifier:identifier];
    
    // Register the beacon region with the location manager and start monitoring and ranging the beacons
    [self.mapLocationManager startMonitoringForRegion:self.beaconRegion];
    [self.mapLocationManager startRangingBeaconsInRegion:self.beaconRegion];
}

// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray *)beacons
               inRegion:(CLBeaconRegion *)region {
    
    // If the beacon is already found, return
    if (self.beaconFound == YES) {
        return;
    }
    
    if ([beacons count] > 0) {
        for (CLBeacon *beacon in beacons) {
            
            // Distance from the beacon
            CLLocationAccuracy accuracy = [beacon accuracy];
            
            if (fabs(accuracy) < BeaconMaxDistance && [[beacon major] intValue] == [majorId intValue] && [[beacon minor] intValue] == [minorId intValue]) {
                
                self.beaconFound = YES;
                
                // Explicit position and floorplan ID at once
                // More information http://docs.indooratlas.com/docs/ios/dev-guide/setting-known-location
                IARegion *region = [IARegion new];
                region.type = kIARegionTypeFloorPlan;
                region.identifier = kFloorplanId;
                region.timestamp = [NSDate date];
                
                CLLocationCoordinate2D beacon = CLLocationCoordinate2DMake([latitudeOfBeacon doubleValue], [longitudeOfBeacon doubleValue]);
                // Distance in meters from beacon times 2. Because beacon accuracy doesn't directly match to horizontal accuracy, it is multiplied by 2. You may experience with other values to find out which provide the best accuracy.
                double distanceFromBeaconX2 = accuracy * 2.0;
                CLLocation *clLoc = [[CLLocation alloc] initWithCoordinate:beacon altitude:-1 horizontalAccuracy:distanceFromBeaconX2 verticalAccuracy:-1 timestamp:[NSDate date]];
                
                IALocation *iaLoc = [IALocation locationWithCLLocation:clLoc];
                iaLoc.region = region;
                self.locationManager.location = iaLoc;
                
                // Displays red circle in the beacon's location once it is detected
                CLLocationCoordinate2D coords = CLLocationCoordinate2DMake([latitudeOfBeacon doubleValue], [longitudeOfBeacon doubleValue]);
                
                MKCircle *circleForBeacon = [MKCircle circleWithCenterCoordinate:coords radius:0.7];
                
                [self.map addOverlay:circleForBeacon];
            }
        }
    }
}

// Stops all the functionality
- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.mapLocationManager stopMonitoringForRegion:self.beaconRegion];
    [self.mapLocationManager stopRangingBeaconsInRegion:self.beaconRegion];
    
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    self.locationManager = nil;
    
    self.map.delegate = nil;
    [self.map removeFromSuperview];
    self.map = nil;
}

@end

