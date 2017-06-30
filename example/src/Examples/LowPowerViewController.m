/**
 * IndoorAtlas SDK Apple Maps example
 */

#import <IndoorAtlas/IALocationManager.h>
#import <IndoorAtlas/IAResourceManager.h>
#import <MapKit/MapKit.h>
#import "LowPowerViewController.h"
#import "CalibrationIndicator.h"
#import "../ApiKeys.h"

@interface LowPowerViewController () <MKMapViewDelegate, IALocationManagerDelegate> {
    IALocationManager *locationManager;
    MKMapView *map;
    MKMapCamera *camera;
    MKCircle *circle;
    IAFloor *currentFloor;
}
@property (nonatomic, strong) CalibrationIndicator *calibrationIndicator;
@end

@implementation LowPowerViewController

-(MKOverlayRenderer *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {
    MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];

    // Change circle color by floor level
    const double hue = (double)(60*currentFloor.level % 360);
    circleRenderer.fillColor =  [UIColor colorWithHue:hue/360.0 saturation:1.0 brightness:1.0 alpha:0.5];
    
    return circleRenderer;
}

- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;
    
    IALocation *ialoc = [locations lastObject];
    CLLocation *l = [ialoc location];
    currentFloor = ialoc.floor;
    NSLog(@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude);
    
    if (circle != nil) {
        [map removeOverlay:circle];
    }
    
    circle = [MKCircle circleWithCenterCoordinate:l.coordinate radius:l.horizontalAccuracy];
    [map addOverlay:circle];
    
    if (camera == nil) {
        // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
        camera = [MKMapCamera cameraLookingAtCenterCoordinate:l.coordinate fromEyeCoordinate:l.coordinate eyeAltitude:300];
        
        // Assign the camera to your map view.
        map.camera = camera;
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager calibrationQualityChanged:(enum ia_calibration)quality
{
    [self.calibrationIndicator setCalibration:quality];
}

/**
 * Authenticate to IndoorAtlas services and request location updates
 */
- (void)requestLocation
{
    locationManager = [IALocationManager sharedInstance];
    
    // Optionally set initial location
    IALocation *location = [IALocation locationWithFloorPlanId:kFloorplanId];
    locationManager.location = location;
    
    // Set delegate to receive location updates
    locationManager.delegate = self;
    
    // Request low-power (and less accurate) locations
    locationManager.desiredAccuracy = kIALocationAccuracyLow;
    
    // Request location updates
    [locationManager startUpdatingLocation];
}

#pragma mark MapsView boilerplate

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    map = [MKMapView new];
    [self.view addSubview:map];
    map.frame = self.view.bounds;
    map.delegate = self;
    
    [self requestLocation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [locationManager stopUpdatingLocation];
    locationManager.desiredAccuracy = kIALocationAccuracyBest;
    locationManager.delegate = nil;
    locationManager = nil;
    map.delegate = nil;
    [map removeFromSuperview];
    map = nil;
}

@end

