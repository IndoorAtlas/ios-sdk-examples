/**
 * IndoorAtlas SDK Apple Maps example
 */

#import <IndoorAtlas/IALocationManager.h>
#import <IndoorAtlas/IAResourceManager.h>
#import <MapKit/MapKit.h>
#import "AppleMapsViewController.h"
#import "../ApiKeys.h"

@interface AppleMapsViewController () <MKMapViewDelegate, IALocationManagerDelegate> {
    IALocationManager *locationManager;
    MKMapView *map;
    MKMapCamera *camera;
    MKCircle *circle;
}
@end

@implementation AppleMapsViewController

-(MKOverlayRenderer *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {
    MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];
    circleRenderer.fillColor =  [UIColor colorWithRed:0 green:0.647 blue:0.961 alpha:1.0];
    return circleRenderer;
}

- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;

    CLLocation *l = [(IALocation*)locations.lastObject location];
    NSLog(@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude);

    if (circle != nil) {
        [map removeOverlay:circle];
    }

    circle = [MKCircle circleWithCenterCoordinate:l.coordinate radius:3];
    [map addOverlay:circle];
    
    if (camera == nil) {
        // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
        camera = [MKMapCamera cameraLookingAtCenterCoordinate:l.coordinate fromEyeCoordinate:l.coordinate eyeAltitude:300];
        
        // Assign the camera to your map view.
        map.camera = camera;
    }
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

    // set delegate to receive location updates
    locationManager.delegate = self;

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
    locationManager.delegate = nil;
    locationManager = nil;
    map.delegate = nil;
    [map removeFromSuperview];
    map = nil;
}

@end

