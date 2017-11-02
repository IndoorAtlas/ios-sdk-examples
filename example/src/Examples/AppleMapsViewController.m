/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <IndoorAtlas/IALocationManager.h>
#import <IndoorAtlas/IAResourceManager.h>
#import <MapKit/MapKit.h>
#import "AppleMapsViewController.h"
#import "CalibrationIndicator.h"
#import "../ApiKeys.h"

@interface AppleMapsViewController () <MKMapViewDelegate, IALocationManagerDelegate> {
    IALocationManager *locationManager;
    MKMapView *map;
    MKMapCamera *camera;
    MKCircle *circle;
}
@property (nonatomic, strong) CalibrationIndicator *calibrationIndicator;
@property (nonatomic, strong) UILabel *label;
@end

@implementation AppleMapsViewController

-(MKOverlayRenderer *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {
    MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];
    circleRenderer.fillColor =  [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:1.0];
    return circleRenderer;
}

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    (void)manager;

    CLLocation *l = [(IALocation *)locations.lastObject location];
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
    
    [self updateLabel];
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

    // Set delegate to receive location updates
    locationManager.delegate = self;

    // Add calibration indicator to navigation bar
    self.calibrationIndicator = [[CalibrationIndicator alloc] initWithNavigationItem:self.navigationItem andCalibration:locationManager.calibration];

    [self.calibrationIndicator setCalibration:locationManager.calibration];

    // Request location updates
    [locationManager startUpdatingLocation];
}

- (void)updateLabel
{
    self.label.text = [NSString stringWithFormat:@"TraceID: %@", [locationManager.extraInfo objectForKey:kIATraceId]];
}

#pragma mark MapsView boilerplate

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    map = [MKMapView new];
    [self.view addSubview:map];
    map.frame = self.view.bounds;
    map.delegate = self;
    
    self.label = [UILabel new];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.numberOfLines = 0;
    self.label.font = [UIFont fontWithName:@"Trebuchet MS" size:14.0f];
    CGRect frame = self.view.bounds;
    frame.size.height = 24 * 2;
    self.label.frame = frame;
    [self.view addSubview:self.label];
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
    [self.label removeFromSuperview];
    self.label = nil;
}

@end

