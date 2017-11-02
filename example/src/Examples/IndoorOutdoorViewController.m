/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import "IndoorOutdoorViewController.h"
#import "IndoorAtlas/IndoorAtlas.h"
#import "AppleMapsOverlayViewController.h"
#import <MapKit/MapKit.h>
#import "../ApiKeys.h"
#import "CalibrationIndicator.h"
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

@interface IndoorOutdoorViewController () <MKMapViewDelegate, IALocationManagerDelegate, UIGestureRecognizerDelegate> {
    MapOverlay *mapOverlay;
    MapOverlayRenderer *mapOverlayRenderer;
    id<IAFetchTask> floorPlanFetch;
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
@property (nonatomic, strong) CalibrationIndicator *calibrationIndicator;
@property (nonatomic, strong) UILabel *label;
@property LocationAnnotation *currentBlueDotAnnotation;
@property CLLocation *currentLocation;
@property MKCircle *radiusCircle;
@end

@implementation IndoorOutdoorViewController
@synthesize mapView;

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
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

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateLocations:(NSArray*)locations
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

- (NSString*)cacheFile {
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
    [self.mapView setShowsUserLocation:NO];
    (void) manager;
    
    if (region.type == kIARegionTypeVenue) {
        [self showToastWithText:@"Entered venue"];
        [self.IALocationManager startUpdatingLocation];
        return;
    } else if (region.type == kIARegionTypeFloorPlan) {

        NSLog(@"Floor plan changed to %@", region.identifier);
        updateCamera = true;
        if (floorPlanFetch != nil) {
            [floorPlanFetch cancel];
            floorPlanFetch = nil;
        }
        
        IAFloorPlan *fp = [self loadFloorPlanWithId:region.identifier];
        if (fp != nil) {
            // use stored floor plan meta data
            self.floorPlan = fp;
            [self fetchImage:fp];
        } else {
            __weak typeof(self) weakSelf = self;
            floorPlanFetch = [self.resourceManager fetchFloorPlanWithId:region.identifier andCompletion:^(IAFloorPlan *floorPlan, NSError *error) {
                if (!error) {
                    self.floorPlan = floorPlan;
                    [weakSelf saveFloorPlan:floorPlan key:region.identifier];
                    [weakSelf fetchImage:floorPlan];
                } else {
                    NSLog(@"There was error during floor plan fetch: %@", error);
                }
            }];
        }
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didExitRegion:(IARegion *)region
{
    if (region.type == kIARegionTypeFloorPlan) {
        return;
    } else if (region.type == kIARegionTypeVenue) {
        [self showToastWithText:@"Exit venue"];
        [self.IALocationManager stopUpdatingLocation];
        [self.mapView removeAnnotation:_currentBlueDotAnnotation];
        [self.mapView setShowsUserLocation:YES];
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager calibrationQualityChanged:(enum ia_calibration)quality
{
    [self.calibrationIndicator setCalibration:quality];
}

/**
 * Request location updates
 */
- (void)requestLocation
{
    self.IALocationManager = [IALocationManager sharedInstance];
    
    // set delegate to receive location updates
    self.IALocationManager.delegate = self;
    
    // Create floor plan manager
    self.resourceManager = [IAResourceManager resourceManagerWithLocationManager:self.IALocationManager];
    
    self.calibrationIndicator = [[CalibrationIndicator alloc] initWithNavigationItem:self.navigationItem andCalibration:self.IALocationManager.calibration];
    
    [self.calibrationIndicator setCalibration:self.IALocationManager.calibration];
    
    // Request location updates
    [self.IALocationManager startUpdatingLocation];
}

- (void)updateLabel
{
    self.label.text = [NSString stringWithFormat:@"TraceID: %@", [self.IALocationManager.extraInfo objectForKey:kIATraceId]];
}

#pragma mark MapsOverlayView boilerplate

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    updateCamera = true;
    
    mapView = [MKMapView new];
    [self.view addSubview:mapView];
    mapView.frame = self.view.bounds;
    mapView.delegate = self;
    
    self.label = [UILabel new];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.numberOfLines = 0;
    self.label.font = [UIFont fontWithName:@"Trebuchet MS" size:14.0f];
    CGRect frame = self.view.bounds;
    frame.size.height = 24 * 2;
    self.label.frame = frame;
    [self.view addSubview:self.label];
    
    [self.mapView setShowsUserLocation:YES];
    
    [self requestLocation];
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    MKCoordinateRegion region;
    MKCoordinateSpan span;
    span.latitudeDelta = 0.005;
    span.longitudeDelta = 0.005;
    CLLocationCoordinate2D location;
    location.latitude = userLocation.coordinate.latitude;
    location.longitude = userLocation.coordinate.longitude;
    region.span = span;
    region.center = location;
    [mapView setRegion:region animated:YES];
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

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.IALocationManager stopUpdatingLocation];
    self.IALocationManager.delegate = nil;
    self.IALocationManager = nil;
    self.resourceManager = nil;
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
    
    [UIView animateWithDuration:5.0 animations:^{
        toastLabel.alpha = 0.0;
    } completion:^(BOOL finished) {
        [toastLabel removeFromSuperview];
    }];
    
}
@end

