/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import "IndoorAtlas/IndoorAtlas.h"
#import <MapKit/MapKit.h>
#import "AppleMapsOverlayViewController.h"
#import "../ApiKeys.h"

#define degreesToRadians(x) (M_PI * x / 180.0)

@implementation MapOverlay

- (id)initWithFloorPlan:(IAFloorPlan *)floorPlan andRotatedRect:(CGRect)rotated
{
    self = [super init];
    if (self != nil) {
        
        _center = floorPlan.center;
        MKMapPoint topLeft = MKMapPointForCoordinate(floorPlan.topLeft);
        _rect = MKMapRectMake(topLeft.x + rotated.origin.x, topLeft.y + rotated.origin.y,
                              rotated.size.width, rotated.size.height);
    }
    return self;
}

- (CLLocationCoordinate2D)coordinate
{
    return self.center;
}

- (MKMapRect)boundingMapRect {
    return _rect;
}

@end

@implementation MapOverlayRenderer

- (void)drawMapRect:(MKMapRect)mapRect
          zoomScale:(MKZoomScale)zoomScale
          inContext:(CGContextRef)ctx
{
    double mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(self.floorPlan.center.latitude);
    CGRect rect = CGRectMake(0, 0, self.floorPlan.widthMeters * mapPointsPerMeter, self.floorPlan.heightMeters * mapPointsPerMeter);

    CGContextTranslateCTM(ctx, -_rotated.origin.x, -_rotated.origin.y);
    // Rotate around top left corner
    CGContextRotateCTM(ctx, degreesToRadians(self.floorPlan.bearing));
    
    UIGraphicsPushContext(ctx);
    [_image drawInRect:rect blendMode:kCGBlendModeNormal alpha:1.0];
    UIGraphicsPopContext();
}

@end

@interface AppleMapsOverlayViewController () <MKMapViewDelegate, IALocationManagerDelegate> {
    MapOverlay *mapOverlay;
    MapOverlayRenderer *mapOverlayRenderer;
    
    UIImage *fpImage;
    NSData *image;
    MKMapCamera *camera;
    Boolean updateCamera;
}
@property (strong) MKCircle *circle;
@property (strong) IAFloorPlan *floorPlan;
@property CGRect rotated;
@property (nonatomic, strong) UILabel *label;
@end

@implementation AppleMapsOverlayViewController
@synthesize map;

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if (overlay == self.circle) {
        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        circleRenderer.fillColor = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:1.0];
        circleRenderer.alpha = 1.f;
        return circleRenderer;
    } else if (overlay == mapOverlay) {
        mapOverlay = overlay;
        mapOverlayRenderer = [[MapOverlayRenderer alloc] initWithOverlay:mapOverlay];
        mapOverlayRenderer.rotated = self.rotated;
        mapOverlayRenderer.floorPlan = self.floorPlan;
        mapOverlayRenderer.image = fpImage;
        return mapOverlayRenderer;
    } else {
        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];
        circleRenderer.fillColor =  [UIColor colorWithRed:1 green:0 blue:0 alpha:1.0];
        return circleRenderer;
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    (void)manager;
    
    CLLocation *l = [(IALocation *)locations.lastObject location];
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
    
    [self updateLabel];
}

- (void)changeMapOverlay
{
    if (self.floorPlan == nil) {
        return;
    }
    
    if (mapOverlay != nil)
        [map removeOverlay:mapOverlay];

    double mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(self.floorPlan.center.latitude);
    double widthMapPoints = self.floorPlan.widthMeters * mapPointsPerMeter;
    double heightMapPoints = self.floorPlan.heightMeters * mapPointsPerMeter;
    CGRect cgRect = CGRectMake(0, 0, widthMapPoints, heightMapPoints);
    double a = degreesToRadians(self.floorPlan.bearing);
    self.rotated = CGRectApplyAffineTransform(cgRect, CGAffineTransformMakeRotation(a));

    mapOverlay = [[MapOverlay alloc] initWithFloorPlan:self.floorPlan andRotatedRect:self.rotated];
    [map addOverlay:mapOverlay];

    // Enable to show red circles on floor plan corners
#if 0
    MKCircle *topLeft = [MKCircle circleWithCenterCoordinate:_floorPlan.topLeft radius:5];
    [map addOverlay:topLeft];

    MKCircle *topRight = [MKCircle circleWithCenterCoordinate:_floorPlan.topRight radius:5];
    [map addOverlay:topRight];

    MKCircle *bottomLeft = [MKCircle circleWithCenterCoordinate:_floorPlan.bottomLeft radius:5];
    [map addOverlay:bottomLeft];
#endif
}

- (NSString *)cacheFile {
    //get the caches directory path
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = [paths objectAtIndex:0];
    BOOL isDir = NO;
    NSError *error;
    // create caches directory if it does not exist
    if (! [[NSFileManager defaultManager] fileExistsAtPath:cachesDirectory isDirectory:&isDir] && isDir == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachesDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    }
    NSString *plistName = [cachesDirectory stringByAppendingPathComponent:@"fpcache.plist"];
    return plistName;
}

// Stores floor plan meta data to NSCachesDirectory
- (void)saveFloorPlan:(IAFloorPlan *)object key:(NSString *)key {
    NSString *cFile = [self cacheFile];
    NSMutableDictionary *cache;
    if ([[NSFileManager defaultManager] fileExistsAtPath:cFile]) {
        cache = [NSMutableDictionary dictionaryWithContentsOfFile:cFile];
    } else {
        cache = [NSMutableDictionary new];
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
    [cache setObject:data forKey:key];
    [cache writeToFile:cFile atomically:YES];
}

// Loads floor plan meta data from NSCachesDirectory
// Remember that if you edit the floor plan position
// from www.indooratlas.com then you must fetch the IAFloorPlan again from server
- (IAFloorPlan *)loadFloorPlanWithId:(NSString *)key {
    NSDictionary *cache = [NSMutableDictionary dictionaryWithContentsOfFile:[self cacheFile]];
    NSData *data = [cache objectForKey:key];
    IAFloorPlan *object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return object;
}

// Image is fetched again each time. It can be cached on device.
- (void)fetchImage:(IAFloorPlan *)floorPlan
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                    ^{
                        NSError *error = nil;
                        NSData *imageData = [NSData dataWithContentsOfURL:[floorPlan imageUrl] options:0 error:&error];
                        if (error) {
                            NSLog(@"Error loading floor plan image: %@", [error localizedDescription]);
                            return;
                        }
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            fpImage = [UIImage imageWithData:imageData];
                            [weakSelf changeMapOverlay];
                        });
                    });
}

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region
{
    (void) manager;
    if (region.type != kIARegionTypeFloorPlan)
        return;
    
    NSLog(@"Floor plan changed to %@", region.identifier);
    updateCamera = true;
    
    if (region.floorplan) {
        self.floorPlan = region.floorplan;
        [self fetchImage:region.floorplan];
    }
}

/**
 * Request location updates
 */
- (void)requestLocation
{
    self.locationManager = [IALocationManager sharedInstance];

    // set delegate to receive location updates
    self.locationManager.delegate = self;

    // Request location updates
    [self.locationManager startUpdatingLocation];
}

- (void)updateLabel
{
    self.label.text = [NSString stringWithFormat:@"Trace ID: %@", [self.locationManager.extraInfo objectForKey:kIATraceId]];
}

#pragma mark MapsOverlayView boilerplate

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    updateCamera = true;
    
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

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    self.locationManager = nil;
    mapOverlayRenderer.image = nil;
    fpImage = nil;
    mapOverlayRenderer = nil;
    
    map.delegate = nil;
    [map removeFromSuperview];
    map = nil;
    
    [self.label removeFromSuperview];
    self.label = nil;
}

@end

