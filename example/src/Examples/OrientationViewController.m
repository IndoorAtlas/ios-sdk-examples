/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <IndoorAtlas/IALocationManager.h>
#import "OrientationViewController.h"
#import "../ApiKeys.h"
#import "PanoramaView.h"

@interface OrientationViewController () <IALocationManagerDelegate> {
        PanoramaView *panoramaView;
}
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) UILabel *informationLabel;
@property (nonatomic, strong) IALocation *location;
@property (nonatomic, strong) IAHeading *heading;
@property (nonatomic, strong) IAAttitude *attitude;
@end

@implementation OrientationViewController
#pragma mark IALocationManagerDelegate methods
/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorLocationManager:(IALocationManager *)manager didUpdateLocations:(NSArray *)locations
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
    
    _informationLabel.text = [NSString stringWithFormat:@"Location: \n%f %f \nQuaternion: \n%f %f %f %f \nHeading: \n%f \nTraceID: \n%@ ", c.latitude, c.longitude, q.w, q.x, q.y, q.z, self.heading.trueHeading, [self.manager.extraInfo objectForKey:kIATraceId]];
}

- (void)setPanoramaAttitude:(IAAttitude *)attitude
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

    // Request location updates
    [self.manager startUpdatingLocation];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self requestLocation];
    
    panoramaView = [[PanoramaView alloc] init];
    [panoramaView setImage:@"telescope_compass_2048.jpg"];
    [panoramaView setOrientToDevice:NO];
    [panoramaView setTouchToPan:NO];
    [panoramaView setPinchToZoom:YES];
    [panoramaView setShowTouches:NO];

    [self setView:panoramaView];

    // Add tap gesture recognizer to hide / show label
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleLabel:)];
    [panoramaView addGestureRecognizer:tapRecognizer];
    
    _informationLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.center.x-self.view.frame.size.width/2, 0, self.view.frame.size.width, 200)];
    _informationLabel.textColor = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:1.0];
    _informationLabel.text = @"";
    _informationLabel.numberOfLines = 20;
    _informationLabel.textAlignment = NSTextAlignmentCenter;
    _informationLabel.adjustsFontSizeToFitWidth = YES;
    [self.view addSubview:_informationLabel];
    
    [self updateLabel];
}

- (void)toggleLabel:(UITapGestureRecognizer *)sender {
    _informationLabel.hidden = !_informationLabel.hidden;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
    [panoramaView removeFromSuperview];
    panoramaView = nil;
    [_informationLabel removeFromSuperview];
    _informationLabel = nil;
}

-(void) glkView:(GLKView *)view drawInRect:(CGRect)rect{
    [panoramaView draw];
}

@end
