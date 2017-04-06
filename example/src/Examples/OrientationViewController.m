/**
 * IndoorAtlas SDK positioning example
 * Copyright 2017 seppo.tomperi@indooratlas.com
 */

#import <IndoorAtlas/IALocationManager.h>
#import "OrientationViewController.h"
#import "../ApiKeys.h"
#import "PanoramaView.h"

@interface OrientationViewController () <IALocationManagerDelegate> {
        PanoramaView *panoramaView;
}
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) IALocation *location;
@property (nonatomic, strong) IAHeading *heading;
@property (nonatomic, strong) IAAttitude *attitude;
@end

@implementation OrientationViewController

#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager*)manager didUpdateLocations:(NSArray*)locations
{
    /* Uses only the last object */
    _location = [locations lastObject];
}

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateHeading:(nonnull IAHeading *)newHeading
{
    _heading = newHeading;
    [self updateLabel];
}

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateAttitude:(nonnull IAAttitude *)newAttitude
{
    _attitude = newAttitude;
    [self setPanoramaAttitude:newAttitude];
    [self updateLabel];
}

- (void)updateLabel
{
    CMQuaternion q = self.attitude.quaternion;
    CLLocationCoordinate2D c = self.location.location.coordinate;

    NSString * htmlString = [NSString stringWithFormat:@"<font color=\"#ff0000\"><div style=\"text-align:center\"><big><b>Location</b><br>%lf,%lf<br><br><b>Orientation</b><br>%lf %lf %lf %lf<br><hr><b>Heading</b><br>%lf</div></big></font>", c.latitude, c.longitude, q.w, q.x, q.y, q.z, self.heading.trueHeading];

    NSAttributedString * attrStr = [[NSAttributedString alloc] initWithData:[htmlString dataUsingEncoding:NSUnicodeStringEncoding] options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType } documentAttributes:nil error:nil];

    [_label setAttributedText:attrStr];
}

- (void)setPanoramaAttitude:(IAAttitude*)attitude
{
    CMQuaternion q = attitude.quaternion;
    GLKQuaternion gq = GLKQuaternionMake(q.x, q.y, q.z, q.w);
    GLKMatrix3 m = GLKMatrix3MakeWithQuaternion(gq);
    GLKMatrix4 matrix = GLKMatrix4Make(m.m00, m.m10, m.m20, 0.0f,
                                       m.m02, m.m12, m.m22, 0.0f,
                                       -m.m01,-m.m11,-m.m21, 0.0f,
                                       0.0f , 0.0f , 0.0f , 1.0f);

    [panoramaView setOffsetMatrix:matrix];
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
    IALocation *location = [IALocation locationWithFloorPlanId:kFloorplanId];
    self.manager.location = location;

    // Request location updates
    [self.manager startUpdatingLocation];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self requestLocation];
    CGRect f = self.view.frame;

    CGRect labelFrame = CGRectMake(f.origin.x, f.origin.y, f.size.width, f.size.height / 2);
    _label = [[UILabel alloc] initWithFrame:labelFrame];

    [_label setTextColor:[UIColor blueColor]];
    [_label setBackgroundColor:[UIColor clearColor]];
    [_label setFont:[UIFont fontWithName: @"Trebuchet MS" size: 14.0f]];
    [_label setNumberOfLines:0];

    panoramaView = [[PanoramaView alloc] init];
    [panoramaView setImage:@"telescope_compass_2048.jpg"];
    [panoramaView setOrientToDevice:NO];
    [panoramaView setTouchToPan:NO];
    [panoramaView setPinchToZoom:YES];
    [panoramaView setShowTouches:NO];

    [self setView:panoramaView];
    [panoramaView addSubview:_label];

    // Add tap gesture recognizer to hide / show label
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleLabel:)];
    [panoramaView addGestureRecognizer:tapRecognizer];

    [self updateLabel];
}

- (void)toggleLabel:(UITapGestureRecognizer*)sender {
    _label.hidden = !_label.hidden;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
}

-(void) glkView:(GLKView *)view drawInRect:(CGRect)rect{
    [panoramaView draw];
}

@end
