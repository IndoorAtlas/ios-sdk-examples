/**
 * IndoorAtlas SDK positioning example
 * Periodically runs IndoorAtlas SDK at background
 * Copyright 2017 Seppo Tomperi <seppo.tomperi@indooratlas.com>
 */

#import <IndoorAtlas/IALocationManager.h>
#import "BackgroundViewController.h"
#import "../ApiKeys.h"

// IndoorAtlas SDK will be started every locationUpdateInterval seconds to
// request a location update
const double locationUpdateInterval = 60.0;

// if no IA location update is received withinlocationUpdateTimeout seconds,
// IA location updates will be stopped to save battery
// locationUpdateTimeout must be smaller than locationUpdateInterval
const double locationUpdateTimeout = 10.0;

// required accuracy for IndoorAtlas location updates. When this accuracy is achieved,
// IA location updates will be stopped to save battery
const double requiredAccuracy = 100.0; // meters

@interface BackgroundViewController () <IALocationManagerDelegate, CLLocationManagerDelegate> {
    UILabel *label;
    NSString *traceId;
    NSString *floorPlanId;
    NSString *venueId;
}
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) CLLocationManager *clManager;
@property (nonatomic, retain) NSTimer *silenceTimer;
@property (nonatomic, retain) NSTimer *locationTimer;
@end

@implementation BackgroundViewController

+ (NSString *)backgroundTimeRemaining
{
    UIApplication *app = [UIApplication sharedApplication];
    NSString *backgroundTime;
    if (app.backgroundTimeRemaining == DBL_MAX) {
        backgroundTime = @"unlimited";
    } else {
        backgroundTime = [@(app.backgroundTimeRemaining) stringValue];
    }

    return backgroundTime;
}

#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;
    CLLocation *l = [(IALocation*)locations.lastObject location];

    [self.locationTimer invalidate];

    // The accuracy of coordinate position depends on the placement of floor plan image.
    NSString * timestamp = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970] * 1000];
    NSLog(@"IA location received %@: (lat,lon, accuracy): %f, %f  accuracy: %lf", timestamp, l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy);

    NSLog(@"background time remaining %@ seconds", [BackgroundViewController backgroundTimeRemaining]);

    // Showing notification is only to see that application is still running and not required for background mode
    [self showNotification:[NSString stringWithFormat:@"Coord: %lf, %lf acc: %lf bg time remaining %@", l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy, [BackgroundViewController backgroundTimeRemaining]]];

    // If location is accurate enough, stop location updates
    if (l.horizontalAccuracy < requiredAccuracy) {
        [self.manager stopUpdatingLocation];
    }
}

#pragma mark IndoorAtlas API Usage

/**
 * Authenticate to IndoorAtlas services and request location updates
 */
- (void)requestLocation
{

    // shuts down IALocationManager if no location is received within timeout seconds
    self.locationTimer = [NSTimer scheduledTimerWithTimeInterval:locationUpdateTimeout target:self
                                                       selector:@selector(timeoutRequestingLocation) userInfo:nil repeats:NO];
    NSLog(@"TraceId %@", [self.manager.extraInfo objectForKey:kIATraceId]);
}

- (void)timeoutRequestingLocation
{
    NSLog(@"Timeout, no location update within %lf seconds.",  locationUpdateTimeout);
    NSLog(@"Background time remaining %@ seconds", [BackgroundViewController backgroundTimeRemaining]);

    [self.manager stopUpdatingLocation];
}

- (void)startBackgroundTask
{
    UIBackgroundTaskIdentifier bgTask;
    UIApplication *app = [UIApplication sharedApplication];
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"Background task ended");
        [app endBackgroundTask:bgTask];
    }];
    self.silenceTimer = [NSTimer scheduledTimerWithTimeInterval:locationUpdateInterval target:self
                                                       selector:@selector(requestLocation) userInfo:nil repeats:YES];

    // CLLocationManager is started called to keep background task alive
    [self.clManager startUpdatingLocation];

    [self requestLocation];
}

#pragma mark CoreLocation Manager

- (void)authenticateCLLocationManager
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];

    if (status == kCLAuthorizationStatusDenied)
    {
        NSLog(@"Location services are disabled in settings.");
    }
    else
    {
        // for iOS 8+
        if ([self.clManager respondsToSelector:@selector(requestAlwaysAuthorization)])
        {
            [self.clManager requestAlwaysAuthorization];
        }
        // for iOS 9+
        if ([self.clManager respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)])
        {
            [self.clManager setAllowsBackgroundLocationUpdates:YES];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    // These locations are not used at all
    NSLog(@"Received CLLocation");
}

- (void)setupCLLocationManager
{
    self.clManager = [CLLocationManager new];
    self.clManager.delegate = self;
    self.clManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
    self.clManager.distanceFilter = 9999999;
    self.clManager.pausesLocationUpdatesAutomatically = NO;
    [self authenticateCLLocationManager];
}

- (void)stopCLLocationManager
{
    [self.clManager stopUpdatingLocation];
    self.clManager = nil;
}

#pragma mark User interface
- (void)showNotification:(NSString *)message
{
    UILocalNotification *notification = [[UILocalNotification alloc]init];
    [notification setAlertBody:message];
    [notification setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    [notification setTimeZone:[NSTimeZone  defaultTimeZone]];
    UIApplication *application = [UIApplication sharedApplication];
    [application setScheduledLocalNotifications:[NSArray arrayWithObject:notification]];
}

- (void)updateLabel
{
    NSString * htmlString = [NSString stringWithFormat:@"<div style=\"text-align:center\"><big><b>Background Example</b><br>If application is backgrounded while this view is showing, this example keeps running periodically on the background and every %.1lf seconds uses IndoorAtlas SDK to get location information. Increases battery usage.</div></big>",locationUpdateInterval];

    NSAttributedString * attrStr = [[NSAttributedString alloc] initWithData:[htmlString dataUsingEncoding:NSUnicodeStringEncoding] options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType } documentAttributes:nil error:nil];

    [label setAttributedText:attrStr];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Create IALocationManager and point delegate to receiver
    self.manager = [IALocationManager sharedInstance];
    self.manager.delegate = self;
    self.manager.desiredAccuracy = kIALocationAccuracyLow;
    
    // Request location updates
    [self.manager startUpdatingLocation];
    
    [self setupCLLocationManager];
    [self startBackgroundTask];

    label = [[UILabel alloc] initWithFrame:self.view.frame];

    [label setTextColor:[UIColor blackColor]];
    [label setBackgroundColor:[UIColor whiteColor]];
    [label setFont:[UIFont fontWithName: @"Trebuchet MS" size: 14.0f]];

    [label setNumberOfLines:0];
    [self updateLabel];

    [self.view addSubview:label];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.manager stopUpdatingLocation];
    [self stopCLLocationManager];
    self.manager.delegate = nil;
    self.manager = nil;
}

@end
