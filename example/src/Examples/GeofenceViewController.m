/**
 * IndoorAtlas SDK positioning example
 */

#import <IndoorAtlas/IALocationManager.h>
#import "GeofenceViewController.h"
#import "../ApiKeys.h"

static NSString *text[2] = {
    @"Tap to add geofence to your current location",
    @"Tap to remove geofence",
};

@interface AppleMapsOverlayViewController () <IALocationManagerDelegate, MKMapViewDelegate>
@end

@interface GeofenceViewController () <IALocationManagerDelegate>
@property (nonatomic, strong) IAGeofence *geofence;
@property (nonatomic, strong) MKCircle *overlay;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property (nonatomic, assign) bool inside;
@end

@implementation GeofenceViewController

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if (overlay == self.overlay) {
        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        circleRenderer.fillColor = [UIColor colorWithRed:!self.inside green:self.inside blue:0 alpha:1.0];
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
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didExitRegion:(IARegion *)region
{
    if (region.type == kIARegionTypeGeofence) {
        self.inside = false;
        
        if (self.overlay) {
            [self.map removeOverlay:self.overlay];
            [self.map addOverlay:self.overlay];
        }
    }
}

- (void)placeGeofence
{
    IALocation *ialoc = self.locationManager.location;
    CLLocation *clloc = ialoc.location;
    
    const double lat_per_meter = 9e-06*cos(M_PI/180.0*clloc.coordinate.latitude);
    const double lon_per_meter = 9e-06;
    
    // Add a circular geofence by adding points with a 5 m radius clockwise
    NSMutableArray<NSNumber*> *edges = [NSMutableArray array];
    for (int i = 1; i <= 10; i++) {
        double lat = clloc.coordinate.latitude + 10*lat_per_meter*sin(-2*M_PI*i/10);
        double lon = clloc.coordinate.longitude + 10*lon_per_meter*cos(-2*M_PI*i/10);
        [edges addObject:[NSNumber numberWithDouble:lat]];
        [edges addObject:[NSNumber numberWithDouble:lon]];
    }
    
    if (self.geofence) {
        [self.locationManager stopMonitoringForGeofence:self.geofence];
        
        [self.map removeOverlay:self.overlay];
        self.overlay = nil;
        self.geofence = nil;
    } else {
        self.overlay = [MKCircle circleWithCenterCoordinate:clloc.coordinate radius:5.0];
        [self.map addOverlay:self.overlay];
        
        self.geofence = [IAPolygonGeofence polygonGeofenceWithIdentifier:@"My geofence" andFloor:ialoc.floor edges:edges];
        
        [self.locationManager startMonitoringForGeofence:self.geofence];
    }
    
    self.label.text = text[(self.geofence != nil)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(placeGeofence)];
    [self.view addGestureRecognizer:self.tap];
    self.label = [UILabel new];
    self.label.text = text[0];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.numberOfLines = 0;
    CGRect frame = self.view.bounds;
    frame.origin.y = (frame.size.height = 24 * 2) / 2;
    self.label.frame = frame;
    [self.view addSubview:self.label];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.view removeGestureRecognizer:self.tap];
    self.tap = nil;
    [self.label removeFromSuperview];
    self.label = nil;
    [self.locationManager stopMonitoringForGeofence:self.geofence];
    self.geofence = nil;
    self.overlay = nil;
}

@end
