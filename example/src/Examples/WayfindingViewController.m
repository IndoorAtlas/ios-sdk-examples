//
//  WayfindingViewController.m
//  sdk-examples
//
//  Copyright © 2018 IndoorAtlas. All rights reserved.
//

#import "WayfindingViewController.h"

#define degreesToRadians(x) (M_PI * x / 180.0)

@interface WayfindingViewController () <MKMapViewDelegate, IALocationManagerDelegate> {
    MapOverlay *mapOverlay;
    MapOverlayRenderer *mapOverlayRenderer;
    id<IAFetchTask> imageFetch;

    UIImage *fpImage;
    NSData *image;
    MKMapCamera *camera;
    Boolean updateCamera;
}
@property (strong) MKCircle *circle;
@property (strong) IAFloorPlan *floorPlan;
@property (nonatomic, strong) IAResourceManager *resourceManager;
@property CGRect rotated;
@property (nonatomic, strong) UILabel *label;

@property MKPolyline *routeLine;
@property MKPolylineRenderer *lineView;
@property MKPointAnnotation *location;
@property MKPinAnnotationView *locationView;
@property MKPointAnnotation *destination;
@property MKPinAnnotationView *destinationView;
@end

@implementation WayfindingViewController
@synthesize map;

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {

    if ([overlay isKindOfClass:[MKPolyline class]])
    {
        MKPolylineRenderer *polylineRenderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];

        polylineRenderer.strokeColor = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:0.7];
        polylineRenderer.lineWidth = 3;

        return polylineRenderer;
    }

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
    IALocation *ialoc = [locations lastObject];
    CLLocation *l = [ialoc location];
    
    NSLog(@"position changed to (lat,lon,floor): %f, %f, %d", l.coordinate.latitude, l.coordinate.longitude, (int)ialoc.floor.level);

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

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateRoute:(IARoute *)route {
    [self plotRoute:route];
}

- (void)changeMapOverlay
{
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
    if (imageFetch != nil) {
        [imageFetch cancel];
        imageFetch = nil;
    }
    __weak typeof(self) weakSelf = self;
    imageFetch = [self.resourceManager fetchFloorPlanImageWithUrl:floorPlan.imageUrl andCompletion:^(NSData *imageData, NSError *error){
        if (!error) {
            fpImage = [[UIImage alloc] initWithData:imageData];
            [weakSelf changeMapOverlay];
        }
    }];
}

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region
{
    (void) manager;
    if (region.type != kIARegionTypeFloorPlan)
        return;

    NSLog(@"Floor plan changed to %@", region.identifier);
    updateCamera = true;
    
    self.floorPlan = region.floorplan;
    [self fetchImage:region.floorplan];
}

/**
 * Request location updates
 */
- (void)requestLocation
{
    self.locationManager = [IALocationManager sharedInstance];

    // set delegate to receive location updates
    self.locationManager.delegate = self;

    // Create floor plan manager
    self.resourceManager = [IAResourceManager resourceManagerWithLocationManager:self.locationManager];
    
    // Locking to indoors
    [self.locationManager lockIndoors:true];

    // Request location updates
    [self.locationManager startUpdatingLocation];
}

- (void)updateLabel
{
    self.label.text = [NSString stringWithFormat:@"Trace ID: %@", [self.locationManager.extraInfo objectForKey:kIATraceId]];
}

#pragma mark MapsOverlayView boilerplate

-(void) handleLongPress:(UILongPressGestureRecognizer*)pressGesture {
    if (pressGesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    CGPoint touchPoint = [pressGesture locationInView:map];
    CLLocationCoordinate2D coord= [map convertPoint:touchPoint toCoordinateFromView:map];
    IAWayfindingRequest *req = [[IAWayfindingRequest alloc] init];
    req.coordinate = coord;
    // Set floor number of the current floor if present
    if (_floorPlan) {
        req.floor = _floorPlan.floor.level;
    } else {
        req.floor = 0;
    }
    @try {
        [self.locationManager startMonitoringForWayfinding:req];
    } @catch(NSException *exception) {
        NSLog(@"loc: %@", exception.reason);
    }
}

- (void) plotRoute:(IARoute *)route {
    if ([route.legs count] == 0) {
        return;
    }

    CLLocationCoordinate2D *coordinateArray = malloc(sizeof(CLLocationCoordinate2D) * route.legs.count + 1);
    CLLocationCoordinate2D coord;
    IARouteLeg *leg = route.legs[0];

    coord.latitude = leg.begin.coordinate.latitude;
    coord.longitude = leg.begin.coordinate.longitude;

    coordinateArray[0] = coord;

    for (int i=0; i < [route.legs count]; i++) {
        CLLocationCoordinate2D coord;
        IARouteLeg *leg = route.legs[i];
        coord.latitude = leg.end.coordinate.latitude;
        coord.longitude = leg.end.coordinate.longitude;
        coordinateArray[i+1] = coord;
    }

    if (_routeLine) {
        [map removeOverlay:_routeLine];
    }
    self.routeLine  = [MKPolyline polylineWithCoordinates:coordinateArray count:route.legs.count + 1];

    free(coordinateArray);
    [map addOverlay:_routeLine];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Load graph
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    
    UILongPressGestureRecognizer *pressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [pressRecognizer setDelaysTouchesBegan:YES];
    pressRecognizer.delegate = self;
    [self.view addGestureRecognizer:pressRecognizer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    updateCamera = true;

    map = [MKMapView new];
    [self.view addSubview:map];
    map.frame = self.view.bounds;
    map.delegate = self;
    map.showsPointsOfInterest = NO;

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
    self.resourceManager = nil;
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
