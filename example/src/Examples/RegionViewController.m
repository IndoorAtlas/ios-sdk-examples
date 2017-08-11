/**
 * IndoorAtlas SDK positioning example
 */

#import <IndoorAtlas/IALocationManager.h>
#import "RegionViewController.h"
#import "../ApiKeys.h"

@interface RegionViewController () <IALocationManagerDelegate>
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) UILabel *regionLabel;
@property (nonatomic, strong) NSString *venueId;
@property (nonatomic, strong) NSString *floorplanId;
@property (nonatomic, strong) NSString *traceId;
@property NSInteger floorLevel;
@property IACertainty floorCertainty;
@end

@implementation RegionViewController

#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    (void)manager;
    IALocation *ialoc = [locations lastObject];
    CLLocation *l = [ialoc location];

    // The accuracy of coordinate position depends on the placement of floor plan image.
    NSLog(@"position changed to coordinate (lat,lon): %f, %f", l.coordinate.latitude, l.coordinate.longitude);

    if (ialoc.floor) {
        self.floorLevel = ialoc.floor.level;
        self.floorCertainty = ialoc.floor.certainty;
    }
    [self updateLabel];
}

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region
{
    if (region.type == kIARegionTypeVenue) {
        self.venueId = region.identifier;
    } else if (region.type == kIARegionTypeFloorPlan) {
        self.floorplanId = region.identifier;
    }
    [self updateLabel];
}

- (void)indoorLocationManager:(IALocationManager *)manager didReceiveExtraInfo:(nonnull NSDictionary *)extraInfo
{
    // First part of traceId has changed, so label will be updated
    [self updateLabel];
}

- (void)updateLabel
{
    // Called each time label is updated to show time variant
    self.traceId = [self.manager.extraInfo objectForKey:kIATraceId];

    NSString *venue = self.venueId ? [NSString stringWithFormat:@"In venue<br>%@", self.venueId] : @"Outside mapped area";
    NSString *fp = self.floorplanId ? [NSString stringWithFormat:@"In floor plan<br>%@", self.floorplanId] : @"No floor plan";

    NSString * htmlString = [NSString stringWithFormat:@"<div style=\"text-align:center\"><big><b>Region information</b><br><br>%@<br><br>%@<br><br><hr><b>Floor level</b><br><h1>%ld</h1>Certainty: %.1lf %%<br><br><b>Trace Id</b><br>%@<br></big></div>",venue, fp, (long)self.floorLevel, self.floorCertainty * 100, self.traceId];

    NSAttributedString * attrStr = [[NSAttributedString alloc] initWithData:[htmlString dataUsingEncoding:NSUnicodeStringEncoding] options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType } documentAttributes:nil error:nil];

    [_regionLabel setAttributedText:attrStr];
}

#pragma mark IndoorAtlas API Usage

/**
 * Authenticate to IndoorAtlas services and request location updates
 */
- (void)requestLocation
{
    // Create IALocationManager and point delegate to receiver
    self.manager = [IALocationManager sharedInstance];
    self.manager.delegate = self;

    // Optionally initial location
    if (kFloorplanId.length) {
        IALocation *location = [IALocation locationWithFloorPlanId:kFloorplanId];
        self.manager.location = location;
    }

    // Request location updates
    [self.manager startUpdatingLocation];
}

#pragma mark boilerplate
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self requestLocation];

    _regionLabel = [[UILabel alloc] initWithFrame:self.view.frame];

    [_regionLabel setTextColor:[UIColor blackColor]];
    [_regionLabel setBackgroundColor:[UIColor whiteColor]];
    [_regionLabel setFont:[UIFont fontWithName: @"Trebuchet MS" size: 14.0f]];

    [_regionLabel setNumberOfLines:0];
    [self updateLabel];

    [self.view addSubview:_regionLabel];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
    [_regionLabel removeFromSuperview];
    _regionLabel = nil;
}

@end
