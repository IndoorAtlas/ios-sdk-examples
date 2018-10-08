/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <IndoorAtlas/IALocationManager.h>
#import <IndoorAtlas/IAResourceManager.h>
#import "ImageViewController.h"
#import "CalibrationIndicator.h"
#import "../ApiKeys.h"

@interface ImageViewController () <IALocationManagerDelegate> {
    id<IAFetchTask> imageFetch;
}
@property (nonatomic, strong) IAFloorPlan *floorPlan;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *circle;
@property (nonatomic, strong) UIView *accuracyCircle;
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) IAResourceManager *resourceManager;
@property (nonatomic, strong) CalibrationIndicator *calibrationIndicator;
@property (nonatomic, strong) UILabel *label;
@end

@implementation ImageViewController

#pragma mark IALocationManager delegate methods

/**
 * Handle location changes
 */
- (void)indoorLocationManager:(IALocationManager *)manager didUpdateLocations:(NSArray *)locations
{

    IALocation *loc = [locations lastObject];

    __weak typeof(self) weakSelf = self;
    if (self.floorPlan != nil) {
        // The accuracy of coordinate position depends on the placement of floor plan image.
        CGPoint point = [self.floorPlan coordinateToPoint:loc.location.coordinate];
        NSLog(@"position changed to pixel point: %fx%f", point.x, point.y);
        [UIView animateWithDuration:(self.circle.hidden ? 0.0f : 0.35f) animations:^{
            weakSelf.circle.center = point;
            weakSelf.accuracyCircle.center = point;
            CGFloat size = loc.location.horizontalAccuracy * [self.floorPlan meterToPixelConversion];
            weakSelf.accuracyCircle.transform = CGAffineTransformMakeScale(size, size);
            [self.view bringSubviewToFront:weakSelf.circle];
        }];
    }

    self.accuracyCircle.hidden = NO;
    self.circle.hidden = NO;
    [self updateLabel];
}

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region
{
    if (region.type != kIARegionTypeFloorPlan)
        return;
    if (region.floorplan) {
        [self fetchFloorplanImage:region.floorplan];
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager calibrationQualityChanged:(enum ia_calibration)quality
{
    [self.calibrationIndicator setCalibration:quality];
}

#pragma mark IndoorAtlas API Usage

/**
 * Fetch floor plan and image with ID
 * These methods are just wrappers around server requests.
 * You will need api key and secret to fetch resources.
 */
- (void)fetchFloorplanImage:(IAFloorPlan *)floorplan
{
    __weak typeof(self) weakSelf = self;
    if (imageFetch != nil) {
        [imageFetch cancel];
        imageFetch = nil;
    }

    imageFetch = [self.resourceManager fetchFloorPlanImageWithUrl:floorplan.imageUrl andCompletion:^(NSData *data, NSError *error) {
        if (error) {
            NSLog(@"Error during floor plan image fetch: %@", error);
            return;
        }

        UIImage *image = [UIImage imageWithData:data];

        float scale = fmin(1.0, fmin(weakSelf.view.bounds.size.width / floorplan.width,
                                    weakSelf.view.bounds.size.height / floorplan.height));

        CGAffineTransform t = CGAffineTransformMakeScale(scale, scale);

        weakSelf.imageView.transform = CGAffineTransformIdentity;
        weakSelf.imageView.image = image;
        weakSelf.imageView.frame = CGRectMake(0, 0, floorplan.width, floorplan.height);
        weakSelf.imageView.transform = t;
        weakSelf.imageView.center = weakSelf.view.center;
        weakSelf.imageView.backgroundColor = [UIColor whiteColor];

        // 1 meters in pixels
        float size = floorplan.meterToPixelConversion;
        weakSelf.circle.transform = CGAffineTransformMakeScale(size, size);
    }];
    weakSelf.floorPlan = floorplan;
}

/**
 * Authenticate to IndoorAtlas services
 */
- (void)requestLocation
{
    // Create IALocationManager and point delegate to receiver
    self.manager = [IALocationManager new];
    self.manager.delegate = self;

    // Create floor plan manager
    self.resourceManager = [IAResourceManager resourceManagerWithLocationManager:self.manager];

    // Add calibration indicator to navigation bar
    self.calibrationIndicator = [[CalibrationIndicator alloc] initWithNavigationItem:self.navigationItem andCalibration:self.manager.calibration];

    [self.calibrationIndicator setCalibration:self.manager.calibration];

    // Request location updates
    [self.manager startUpdatingLocation];
}

- (void)updateLabel
{
    self.label.text = [NSString stringWithFormat:@"TraceID: %@", [self.manager.extraInfo objectForKey:kIATraceId]];
}

#pragma mark ImageViewContoller boilerplate

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.backgroundColor = [UIColor whiteColor];
    self.imageView = [UIImageView new];
    [self.view addSubview:self.imageView];
    
    self.accuracyCircle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.accuracyCircle.backgroundColor = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:0.4];
    self.accuracyCircle.layer.cornerRadius = self.accuracyCircle.frame.size.width / 2;
    self.accuracyCircle.hidden = YES;
    [self.imageView addSubview:self.accuracyCircle];
    
    self.imageView.frame = self.view.frame;
    self.circle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.circle.backgroundColor = [UIColor colorWithRed:0.08627 green:0.5059 blue:0.9843 alpha:1.0];
    self.circle.layer.cornerRadius = self.circle.frame.size.width / 2;
    self.circle.layer.borderColor = [[UIColor colorWithRed:1 green:1 blue:1 alpha:1] CGColor];
    self.circle.layer.borderWidth = 0.1;
    self.circle.hidden = YES;
    [self.imageView addSubview:self.circle];

    self.label = [UILabel new];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.numberOfLines = 0;
    self.label.font = [UIFont fontWithName:@"Trebuchet MS" size:14.0f];
    self.label.textColor = [UIColor blackColor];
    CGRect frame = self.view.bounds;
    frame.size.height = 24 * 2;
    self.label.frame = frame;
    [self.view addSubview:self.label];
    
    [self requestLocation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
    self.resourceManager = nil;
    self.imageView.image = nil;
    self.imageView = nil;
    [self.label removeFromSuperview];
    self.label = nil;
}

@end

/* vim: set ts=8 sw=4 tw=0 ft=objc :*/
