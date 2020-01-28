//
//  MapViewController.m
//  sdk-examples
//
//  Copyright © 2018 IndoorAtlas. All rights reserved.
//

#import "MapViewController.h"

#define degreesToRadians(x) (M_PI * x / 180.0)

typedef enum {
    blueDot = 0,
    accuracyCircle
}LocationType;

@interface LocationAnnotation: MKPointAnnotation
@property double radius;
@property LocationType locationType;
-(id)initWithLocationType:(LocationType)locationType andRadius:(double)radius;
@end

@implementation LocationAnnotation
-(id)initWithLocationType:(LocationType)locationType andRadius:(double)radius
{
    self.radius = radius;
    self.locationType = locationType;
    self = [super init];
    return self;
}
@end

@interface MapViewController () <MKMapViewDelegate, IALocationManagerDelegate, UIGestureRecognizerDelegate> {
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

@property MKPolyline *routeLine;
@property MKPolylineRenderer *lineView;
@property MKPointAnnotation *location;
@property MKPinAnnotationView *locationView;
@property MKPointAnnotation *destination;
@property MKPinAnnotationView *destinationView;
@property LocationAnnotation *currentBlueDotAnnotation;
@property CLLocation *currentLocation;
@property MKCircle *radiusCircle;
@end

@implementation MapViewController
@synthesize mapView;

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {

    if ([overlay isKindOfClass:[MKPolyline class]])
    {
        MKPolylineRenderer *polylineRenderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline*)overlay];

        polylineRenderer.strokeColor = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:0.7];
        polylineRenderer.lineWidth = 3;

        return polylineRenderer;
    }

    if (overlay == self.circle) {
        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        circleRenderer.fillColor = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:1.0];
        circleRenderer.alpha = 1.f;
        circleRenderer.strokeColor = [UIColor whiteColor];
        circleRenderer.lineWidth = 3;
        return circleRenderer;
    } else if (overlay == mapOverlay) {
        mapOverlay = overlay;
        mapOverlayRenderer = [[MapOverlayRenderer alloc] initWithOverlay:overlay];
        mapOverlayRenderer.rotated = self.rotated;
        mapOverlayRenderer.floorPlan = self.floorPlan;
        mapOverlayRenderer.image = fpImage;
        return mapOverlayRenderer;
    } else {
        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];
        circleRenderer.fillColor =  [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:0.4];
        return circleRenderer;
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    (void)manager;
    
    CLLocation *l = [(IALocation *)locations.lastObject location];
    NSLog(@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude);
    
    if (self.radiusCircle != nil) {
        [mapView removeOverlay:self.radiusCircle];
    }
    
    LocationType type = blueDot;
    _currentLocation = l;
    
    if (self.currentBlueDotAnnotation == nil) {
        self.currentBlueDotAnnotation = [[LocationAnnotation alloc]initWithLocationType:type andRadius:25];
        [mapView addAnnotation:self.currentBlueDotAnnotation];
    }
    self.currentBlueDotAnnotation.coordinate = l.coordinate;
    
    self.radiusCircle = [MKCircle circleWithCenterCoordinate:l.coordinate radius:l.horizontalAccuracy];
    [mapView addOverlay:self.radiusCircle];
    
    if (updateCamera) {
        updateCamera = false;
        if (camera == nil) {
            // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
            camera = [MKMapCamera cameraLookingAtCenterCoordinate:l.coordinate fromEyeCoordinate:l.coordinate eyeAltitude:300];
            
            // Assign the camera to your map view.
            mapView.camera = camera;
        } else {
            camera.centerCoordinate = l.coordinate;
        }
    }
    
    [self updateLabel];
}

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateRoute:(IARoute *)route {
    if ([self hasArrivedToDestination:route]) {
        [self showToastWithText:@"You have arrived to destination"];
        [self.locationManager stopMonitoringForWayfinding];
        [self.locationManager lockIndoors:false];
        if (_routeLine) {
            [mapView removeOverlay:_routeLine];
        }
    } else {
        [self plotRoute:route];
    }
}

- (void)changeMapOverlay
{
    if (mapOverlay != nil)
        [mapView removeOverlay:mapOverlay];

    double mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(self.floorPlan.center.latitude);
    double widthMapPoints = self.floorPlan.widthMeters * mapPointsPerMeter;
    double heightMapPoints = self.floorPlan.heightMeters * mapPointsPerMeter;
    CGRect cgRect = CGRectMake(0, 0, widthMapPoints, heightMapPoints);
    double a = degreesToRadians(self.floorPlan.bearing);
    self.rotated = CGRectApplyAffineTransform(cgRect, CGAffineTransformMakeRotation(a));

    mapOverlay = [[MapOverlay alloc] initWithFloorPlan:self.floorPlan andRotatedRect:self.rotated];
    [mapView addOverlay:mapOverlay];
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
    if (region.type == kIARegionTypeFloorPlan && region.floorplan) {
        NSLog(@"Floor plan changed to %@", region.identifier);
        updateCamera = true;
        self.floorPlan = region.floorplan;
        [self fetchImage:region.floorplan];
    } else if (region.type == kIARegionTypeVenue && region.venue) {
        [self showToastWithText:[NSString stringWithFormat:@"Enter venue %@", region.venue.name]];
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didExitRegion:(IARegion *)region
{
    if (region.type == kIARegionTypeFloorPlan) {
        return;
    } else if (region.type == kIARegionTypeVenue) {
        if (region.venue) {
            [self showToastWithText:[NSString stringWithFormat:@"Exit venue %@", region.venue.name]];
        }
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
    
    // Set the desired accuracy of location updates to one of the following:
    // kIALocationAccuracyBest : High accuracy mode (default)
    // kIALocationAccuracyLow : Low accuracy mode, uses less power
    self.locationManager.desiredAccuracy = kIALocationAccuracyBest;

    // Request location updates
    [self.locationManager startUpdatingLocation];
}

- (void)updateLabel
{
    self.label.text = [NSString stringWithFormat:@"Trace ID: %@", [self.locationManager.extraInfo objectForKey:kIATraceId]];
}

#pragma mark MapsOverlayView boilerplate

// Method for initiating wayfinding to the coordinates pressed on screen
-(void) handleLongPress:(UILongPressGestureRecognizer*)pressGesture {
    if (pressGesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    CGPoint touchPoint = [pressGesture locationInView:mapView];
    CLLocationCoordinate2D coord= [mapView convertPoint:touchPoint toCoordinateFromView:mapView];
    IAWayfindingRequest *req = [[IAWayfindingRequest alloc] init];
    req.coordinate = coord;
    // Set floor number of the current floor
    if (_floorPlan) {
        req.floor = _floorPlan.floor.level;
        
        // Locking to indoors 
        [self.locationManager lockIndoors:true];
        
        [self.locationManager startMonitoringForWayfinding:req];
    } else {
        NSLog(@"Not sending wayfinding request: no floor plan");
    }
}

// Method for checking if user has arrived to the wayfinding destination
- (bool) hasArrivedToDestination: (IARoute *) route {
    // empty routes are only returned when there is a problem, for example,
    // missing or disconnected routing graph
    if (route.legs.count == 0) {
        return false;
    }
    
    const double FINISH_THRESHOLD_METERS = 8.0;
    double routeLength = 0.0;
    for (IARouteLeg *leg in route.legs) {
        routeLength += leg.length;
    }
    return routeLength < FINISH_THRESHOLD_METERS;
}

// Method for plotting the wayfinding route
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
        [mapView removeOverlay:_routeLine];
    }
    self.routeLine  = [MKPolyline polylineWithCoordinates:coordinateArray count:route.legs.count + 1];

    free(coordinateArray);
    [mapView addOverlay:_routeLine];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Add screen press recogniser for adding wayfinding destinations
    UILongPressGestureRecognizer *pressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [pressRecognizer setDelaysTouchesBegan:YES];
    pressRecognizer.delegate = self;
    [self.view addGestureRecognizer:pressRecognizer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    updateCamera = true;
    
    mapView = [MKMapView new];
    [self.view addSubview:mapView];
    mapView.frame = self.view.bounds;
    mapView.delegate = self;
    
    // Add text field for the trace id
    self.label = [UILabel new];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.numberOfLines = 0;
    self.label.font = [UIFont fontWithName:@"Trebuchet MS" size:14.0f];
    CGRect frame = self.view.bounds;
    frame.size.height = 24 * 2;
    self.label.frame = frame;
    [self.view addSubview:self.label];
    
    [self.mapView setShowsUserLocation:NO];
    
    [self requestLocation];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]])
    {
        NSLog(@"annotation: no");
        return nil;
    }
    
    else if ([annotation isKindOfClass:[MKPinAnnotationView class]]) {
        MKPinAnnotationView *view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Annotation"];
        return view;
    }
    
    else if ([annotation isKindOfClass:[LocationAnnotation class]])
    {
        LocationAnnotation *circleAnnotation = (LocationAnnotation *)annotation;
        
        NSString *type = @"";
        UIColor *color = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:1.0];
        CGFloat alpha = 1.0;
        CGFloat borderWidth = 0;
        UIColor *borderColor = [UIColor colorWithRed:0 green:30/255 blue:80/255 alpha:1];
        
        if (circleAnnotation.locationType == blueDot) {
            type = @"blueDot";
            borderColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
            borderWidth = 3;
        } else if (circleAnnotation.locationType == accuracyCircle) {
            type = @"accuracyCircle";
            alpha = 0.2;
            borderWidth = 0;
        }
        
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:type];
        if (annotationView)
        {
            annotationView.annotation = circleAnnotation;
        }
        else
        {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:circleAnnotation
                                                          reuseIdentifier:type];
        }
        
        annotationView.canShowCallout = NO;
        annotationView.frame = CGRectMake(0, 0, circleAnnotation.radius, circleAnnotation.radius);
        annotationView.backgroundColor = color;
        annotationView.alpha = alpha;
        annotationView.layer.borderWidth = borderWidth;
        annotationView.layer.borderColor = [borderColor CGColor];
        annotationView.layer.cornerRadius = annotationView.frame.size.width / 2;
        
        return annotationView;
    }
    return nil;
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.locationManager stopMonitoringForWayfinding];
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    self.locationManager = nil;
    mapOverlayRenderer.image = nil;
    fpImage = nil;
    mapOverlayRenderer = nil;
    
    mapView.delegate = nil;
    [mapView removeFromSuperview];
    mapView = nil;
    
    [self.label removeFromSuperview];
    self.label = nil;
}

- (void)showToastWithText:(NSString *) text {
    UILabel *toastLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2 - 150, self.view.frame.size.height/2 -40, 300, 35)];
    toastLabel.backgroundColor = [UIColor blackColor];
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.text = text;
    toastLabel.alpha = 0.8;
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds = YES;
    [self.view addSubview:toastLabel];
    
    [UIView animateWithDuration:3.0 animations:^{
        toastLabel.alpha = 0.0;
    } completion:^(BOOL finished) {
        [toastLabel removeFromSuperview];
    }];
    
}
@end
