/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <IndoorAtlas/IALocationManager.h>
#import "GeofenceViewController.h"
#import "../ApiKeys.h"

static NSString *text[2] = {
    @"Tap to add geofence",
    @"Tap to remove geofence",
};

@interface AppleMapsOverlayViewController () <IALocationManagerDelegate, MKMapViewDelegate>
@property (nonatomic, strong) UILabel *label;
@end

@interface GeofenceViewController () <IALocationManagerDelegate>
@property (nonatomic, strong) IAGeofence *geofence;
@property (nonatomic, strong) MKCircle *overlay;
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property (nonatomic, assign) bool inside;
@property (nonatomic, strong) UILabel *bottomLabel;
@end

@implementation GeofenceViewController

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if (overlay == self.overlay) {
        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        circleRenderer.fillColor = [UIColor colorWithRed:!self.inside green:self.inside blue:0 alpha:0.7];
        return circleRenderer;
    }
    
    return [super mapView:mapView rendererForOverlay:overlay];
}

#pragma mark IALocationManagerDelegate methods

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region
{
    [super indoorLocationManager:manager didEnterRegion:region];
    
    if (region.type == kIARegionTypeGeofence) {
        self.inside = true;
        
        if (self.overlay) {
            [self.map removeOverlay:self.overlay];
            [self.map addOverlay:self.overlay];
        }
        
        // IAGeofence is subclass of IARegion
        NSLog(@"Inside geofence %@", region);
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didExitRegion:(IARegion *)region
{
    if (region.type == kIARegionTypeGeofence) {
        self.inside = false;
        
        if (self.overlay) {
            [self.map removeOverlay:self.overlay];
            [self.map addOverlay:self.overlay];
            
            // IAGeofence is subclass of IARegion
            NSLog(@"Outside geofence %@", region);
        }
    }
}

- (void)placeGeofence:(UITapGestureRecognizer *)recognizer
{
    CGPoint point = [recognizer locationInView:self.map];
    CLLocationCoordinate2D tapLocation = [self.map convertPoint:point toCoordinateFromView:self.view];
    
    const double lat_per_meter = 9e-06*cos(M_PI/180.0*tapLocation.latitude);
    const double lon_per_meter = 9e-06;
    
    // Add a circular geofence by adding points with a 5 m radius clockwise
    NSMutableArray<NSNumber*> *edges = [NSMutableArray array];
    for (int i = 1; i <= 10; i++) {
        double lat = tapLocation.latitude + 10*lat_per_meter*sin(-2*M_PI*i/10);
        double lon = tapLocation.longitude + 10*lon_per_meter*cos(-2*M_PI*i/10);
        [edges addObject:[NSNumber numberWithDouble:lat]];
        [edges addObject:[NSNumber numberWithDouble:lon]];
    }
    
    if (self.geofence) {
        [self.locationManager stopMonitoringForGeofence:self.geofence];
        
        [self.map removeOverlay:self.overlay];
        self.overlay = nil;
        self.geofence = nil;
    } else {
        self.inside = false;
        self.overlay = [MKCircle circleWithCenterCoordinate:tapLocation radius:5.0];
        [self.map addOverlay:self.overlay];

        IALocation *ialoc = self.locationManager.location;
        self.geofence = [IAPolygonGeofence polygonGeofenceWithIdentifier:@"My geofence" andFloor:ialoc.floor edges:edges];
        
        [self.locationManager startMonitoringForGeofence:self.geofence];
    }
    
    [self updateLabel];
}

- (void)updateLabel
{
    self.label.text = [NSString stringWithFormat:@"%@", text[(self.geofence != nil)]];
    self.bottomLabel.text = [NSString stringWithFormat:@"Trace ID: %@", [self.locationManager.extraInfo objectForKey:kIATraceId]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(placeGeofence:)];
    [self.view addGestureRecognizer:self.tap];
    self.label.font = [UIFont fontWithName:@"Trebuchet MS" size:18.0f];
    
    self.bottomLabel = [UILabel new];
    self.bottomLabel.textAlignment = NSTextAlignmentCenter;
    self.bottomLabel.numberOfLines = 0;
    self.bottomLabel.font = [UIFont fontWithName:@"Trebuchet MS" size:14.0f];
    CGRect frame = self.view.bounds;
    frame.size.height = 24 * 6;
    frame.origin.y = self.view.bounds.size.height - frame.size.height - 14;
    self.bottomLabel.frame = frame;
    [self.view addSubview:self.bottomLabel];
    
    [self updateLabel];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.view removeGestureRecognizer:self.tap];
    self.tap = nil;
    [self.locationManager stopMonitoringForGeofence:self.geofence];
    [self.bottomLabel removeFromSuperview];
    self.geofence = nil;
    self.overlay = nil;
}

@end
