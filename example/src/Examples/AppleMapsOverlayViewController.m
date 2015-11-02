/**
 * IndoorAtlas SDK Apple Maps Overlay example
 */

#import <IndoorAtlas/IALocationManager.h>
#import <IndoorAtlas/IAResourceManager.h>
#import <MapKit/MapKit.h>
#import "AppleMapsOverlayViewController.h"
#import "../ApiKeys.h"

#define degreesToRadians(x) (M_PI * x / 180.0)

@interface MapOverlay : NSObject <MKOverlay>
- (id)initWithFloorPlan:(IAFloorPlan*)floorPlan;
- (MKMapRect)boundingMapRect;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property CLLocationCoordinate2D center;
@property MKMapRect rect;
@property CGAffineTransform p2w;
@end

@implementation MapOverlay

- (id)initWithFloorPlan:(IAFloorPlan *)floorPlan
{
    self = [super init];
    if (self != nil) {

        _center = floorPlan.center;

        double mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(self.center.latitude);
        double widthMapPoints = floorPlan.widthMeters * mapPointsPerMeter;
        double heightMapPoints = floorPlan.heightMeters * mapPointsPerMeter;
        MKMapPoint topLeft = MKMapPointForCoordinate(floorPlan.topLeft);
        _rect = MKMapRectMake(topLeft.x, topLeft.y,
                              widthMapPoints,heightMapPoints);
    }
    return self;
}

- (CLLocationCoordinate2D)coordinate
{
    return self.center;
}

- (MKMapRect)boundingMapRect {
    return self.rect;
}

@end

@interface MapOverlayView : MKOverlayView
@property (strong, readwrite) IAFloorPlan *floorPlan;
@property (strong, readwrite) UIImage *image;
@end

@implementation MapOverlayView

- (void)drawMapRect:(MKMapRect)mapRect
          zoomScale:(MKZoomScale)zoomScale
          inContext:(CGContextRef)ctx
{
    MKMapRect theMapRect = [self.overlay boundingMapRect];
    CGRect theRect = [self rectForMapRect:theMapRect];

    // Rotate around top left corner
    CGContextRotateCTM(ctx, degreesToRadians(self.floorPlan.bearing));
    
    UIGraphicsPushContext(ctx);
    [_image drawInRect:theRect blendMode:kCGBlendModeNormal alpha:1.0];
    UIGraphicsPopContext();
}

@end

@interface AppleMapsOverlayViewController () <MKMapViewDelegate, IALocationManagerDelegate> {
    IALocationManager *locationManager;
    IAResourceManager *resourceManager;

    UIImage *fpImage;
    NSData *image;
    MKMapView *map;
    MKMapCamera *camera;
    Boolean updateCamera;
}
@property (strong) MKCircle *circle;
@property (strong) MapOverlay *mapOverlay;
@property (strong) IAFloorPlan *floorPlan;
@end

@implementation AppleMapsOverlayViewController

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    if (overlay == self.circle) {
        MKCircleView *circleView = [[MKCircleView alloc] initWithCircle:(MKCircle *)overlay];
        circleView.fillColor =  [UIColor colorWithRed:0 green:0.647 blue:0.961 alpha:1.0];
        return circleView;
    } else if (overlay == self.mapOverlay) {
        MapOverlay *mapOverlay = overlay;
        MapOverlayView *mapOverlayView = [[MapOverlayView alloc] initWithOverlay:mapOverlay];
        mapOverlayView.floorPlan = self.floorPlan;
        mapOverlayView.image = fpImage;
        return mapOverlayView;
    } else {
        MKCircleView *circleView = [[MKCircleView alloc] initWithCircle:(MKCircle *)overlay];
        circleView.fillColor =  [UIColor colorWithRed:1 green:0 blue:0 alpha:1.0];
        return circleView;
    }
}

- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;

    CLLocation *l = [(IALocation*)locations.lastObject location];
    NSLog(@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude);

    if (self.circle != nil) {
        [map removeOverlay:self.circle];
    }

    self.circle = [MKCircle circleWithCenterCoordinate:l.coordinate radius:1];
    [map addOverlay:self.circle];
    if (updateCamera) {
        updateCamera = false;
        if (camera == nil) {
            // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
            camera = [MKMapCamera cameraLookingAtCenterCoordinate:l.coordinate fromEyeCoordinate:l.coordinate eyeAltitude:300];

            // Assign the camera to your map view.
            map.camera = camera;
        } else {
            camera.centerCoordinate = l.coordinate;
        }
    }
}

- (void)changeMapOverlay
{
    if (self.mapOverlay != nil)
        [map removeOverlay:self.mapOverlay];

    self.mapOverlay = [[MapOverlay alloc] initWithFloorPlan:self.floorPlan];
    [map addOverlay:self.mapOverlay];
}

- (void)indoorLocationManager:(IALocationManager*)manager didEnterRegion:(IARegion*)region
{
    (void) manager;
    NSLog(@"Floor plan changed to %@", region.identifier);
    updateCamera = true;

    [resourceManager fetchFloorPlanWithId:region.identifier andCompletion:^(IAFloorPlan *floorPlan, NSError *error) {
        if (!error) {
            self.floorPlan =floorPlan;
            [resourceManager fetchFloorPlanImageWithId:region.identifier andCompletion:^(NSData *imageData, NSError *error){
                 __weak typeof(self) weakSelf = self;
                fpImage = [[UIImage alloc] initWithData:imageData];
                [weakSelf changeMapOverlay];
            }];
        } else {
            NSLog(@"Error fetching floorplan");
        }
    }];
}

/**
 * Authenticate to IndoorAtlas services and request location updates
 */
- (void)authenticateAndRequestLocation
{
    locationManager = [IALocationManager new];
    // Set IndoorAtlas API key and secret
    [locationManager setApiKey:kAPIKey andSecret:kAPISecret];

    // Optionally set initial location
    IALocation *location = [IALocation locationWithFloorPlanId:kFloorplanId];
    locationManager.location = location;

    // set delegate to receive location updates
    locationManager.delegate = self;

    // Create floor plan manager
    resourceManager = [IAResourceManager resourceManagerWithLocationManager:locationManager];

    // Request location updates
    [locationManager startUpdatingLocation];
}


#pragma mark MapsOverlayView boilerplate

- (void)viewDidLoad {
    [super viewDidLoad];
    updateCamera = true;

    map = [MKMapView new];
    [self.view addSubview:map];
    map.frame = self.view.bounds;
    map.delegate = self;
    
    [self authenticateAndRequestLocation];
}
@end

