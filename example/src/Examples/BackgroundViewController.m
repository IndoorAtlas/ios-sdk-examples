/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <IndoorAtlas/IALocationManager.h>
#import "BackgroundViewController.h"
#import "../ApiKeys.h"

@interface BackgroundViewController () <IALocationManagerDelegate, CLLocationManagerDelegate> {
    UILabel *label;
    NSString *floorPlanId;
    NSString *venueId;
}
@property (nonatomic) IALocationManager *manager;
@property (nonatomic) CLLocationManager *clManager;
@property (nonatomic) NSDate *lastShow;
@end

@implementation BackgroundViewController

#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;
    CLLocation *l = [(IALocation*)locations.lastObject location];

    // The accuracy of coordinate position depends on the placement of floor plan image.
    NSString * timestamp = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970] * 1000];
    NSLog(@"IA location received %@: (lat,lon, accuracy): %f, %f  accuracy: %lf", timestamp, l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy);


    // Showing notification is only to see that application is still running and not required for background mode
    [self showNotification:[NSString stringWithFormat:@"Coord: %lf, %lf acc: %lf", l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy]];
}

#pragma mark IndoorAtlas API Usage

- (void)startBackgroundTask
{
    // CLLocationManager is started called to keep background task alive
    [self.clManager startUpdatingLocation];
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
    self.clManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.clManager.distanceFilter = kCLDistanceFilterNone;
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
    if (self.lastShow && [self.lastShow timeIntervalSinceNow] < 1.0)
        return;

    self.lastShow = [NSDate date];
    UILocalNotification *notification = [[UILocalNotification alloc]init];
    [notification setAlertBody:message];
    [notification setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    [notification setTimeZone:[NSTimeZone  defaultTimeZone]];
    UIApplication *application = [UIApplication sharedApplication];
    [application setScheduledLocalNotifications:[NSArray arrayWithObject:notification]];
}

- (void)updateLabel
{
    NSString *htmlString = [NSString stringWithFormat:@"<div style=\"text-align:center\"><big><b>Background Example</b><br/><br/><b>Trace ID</b><br/>%@</big></div>", [self.manager.extraInfo objectForKey:kIATraceId]];

    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithData:[htmlString dataUsingEncoding:NSUnicodeStringEncoding] options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType } documentAttributes:nil error:nil];

    [label setAttributedText:attrStr];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.backgroundColor = [UIColor whiteColor];

    // Create IALocationManager and point delegate to receiver
    self.manager = [IALocationManager sharedInstance];
    self.manager.delegate = self;

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
    [label removeFromSuperview];
    label = nil;
}

@end
