/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import "ARViewController.h"
#import "ARUtils.h"
#import "PaddingLabel.h"
#import <IndoorAtlas/IndoorAtlas.h>
#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>
#import "SVProgressHUD.h"

@interface ARViewController () <IALocationManagerDelegate, ARSCNViewDelegate, ARSessionDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) ARSCNView* arView;
@property (nonatomic, strong) SCNNode* target;
@property (nonatomic, strong) SCNNode* arrow;
@property (nonatomic, strong) IALocationManager* indooratlas;
@property (nonatomic, strong) NSMutableArray<SCNNode*>* waypoints;
@property (nonatomic, copy) NSArray<ARPOI*>* pois;
@property (nonatomic, strong) IAFloorPlan* floorPlan;
@property (nonatomic, strong) PaddingLabel* infoLabel;
@property (nonatomic, assign) BOOL wayfindingStartedYet;
@property (nonatomic, strong) IAWayfindingRequest* wayfindingTarget;
@property (nonatomic, strong) UISearchBar* searchBar;
@property (nonatomic, strong) UITableView* searchTableView;
@property (nonatomic, copy) NSArray<ARPOI*>* searchDataSource;
@property (nonatomic, strong) UIView* statusBarBg;
@end

@implementation ARViewController

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.indooratlas = IALocationManager.sharedInstance;
    self.waypoints = [NSMutableArray array];
    self.pois = @[];
    self.infoLabel = [[PaddingLabel alloc] init];
    self.wayfindingStartedYet = NO;
    self.searchDataSource = @[];
    self.statusBarBg = [[UIView alloc] init];
}

- (CGFloat)statusBarHeight {
    CGSize statusBarSize = [UIApplication sharedApplication].statusBarFrame.size;
    return MIN(statusBarSize.width, statusBarSize.height);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Show spinner while waiting for location information from IALocationManage
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:NSLocalizedString(@"Waiting for location data", comment: @"")];
    });
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    self.arView = [[ARSCNView alloc] initWithFrame:self.view.bounds];
    self.arView.showsStatistics = NO;
    self.arView.automaticallyUpdatesLighting = YES;
    self.arView.session.delegate = self;
    [self.arView.session runWithConfiguration:[[self class] configuration]];
    self.arView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.arView.delegate = self;
    [self.view addSubview:self.arView];
    
    SCNMaterial* outline = [SCNMaterial material];
    outline.diffuse.contents = [UIColor whiteColor];
    outline.cullMode = SCNCullModeFront;
    
    do {
        self.target = [SCNScene sceneNamed:@"Models.scnassets/finish.obj"].rootNode.childNodes.firstObject;
        self.target.geometry.materials = @[outline];
        SCNNode* base = deepCopyNode(self.target);
        base.scale = SCNVector3Make(0.9, 0.9, 0.9);
        SCNMaterial* material = [SCNMaterial material];
        material.diffuse.contents = [UIImage imageNamed:@"Models.scnassets/finish.png"];
        base.geometry.materials = @[material];
        [self.target addChildNode:base];
    } while (NO);
    
    do {
        self.arrow = [SCNScene sceneNamed:@"Models.scnassets/arrow_stylish.obj"].rootNode.childNodes.firstObject;
        self.arrow.geometry.materials = @[outline];
        SCNNode* base = deepCopyNode(self.arrow);
        base.scale = SCNVector3Make(0.9, 0.9, 0.9);
        SCNMaterial* material = [SCNMaterial material];
        material.diffuse.contents = [UIColor colorWithRed:22.0/255.0 green:129.0/255.0 blue:251.0/255.0 alpha:1.0];
        base.geometry.materials = @[material];
        [self.arrow addChildNode:base];
    } while (NO);
    
    self.infoLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.infoLabel.alpha = 0.0;
    self.infoLabel.layer.cornerRadius = 18.0;
    self.infoLabel.clipsToBounds = YES;
    self.infoLabel.text = @"Walk 20 meters to any direction so we can orient you. Avoid pointing the camera at blank walls.";
    self.infoLabel.textColor = [UIColor whiteColor];
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.numberOfLines = 5;
    [self.arView addSubview:self.infoLabel];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.infoLabel.widthAnchor constraintEqualToAnchor:self.arView.widthAnchor constant:-8.0].active = YES;
    [self.infoLabel.trailingAnchor constraintEqualToAnchor:self.arView.trailingAnchor constant:-8.0/2.0].active = YES;
    [self.infoLabel.heightAnchor constraintEqualToConstant:120.0].active = YES;
    [self.infoLabel.topAnchor constraintEqualToAnchor:self.arView.topAnchor constant:88].active = YES;

    self.searchBar = [[UISearchBar alloc] init];
    [self.searchBar setBackgroundImage:[[UIImage alloc] init] forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.placeholder = @"Search POIs";
    [self.searchBar sizeToFit];
    self.searchBar.showsCancelButton = YES;
    self.searchBar.delegate = self;
    self.navigationItem.titleView = self.searchBar;
    [self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [[UIImage alloc] init];
    self.navigationController.navigationBar.translucent = YES;
    self.navigationController.view.backgroundColor = [UIColor clearColor];
    self.searchTableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    self.searchTableView.hidden = YES;
    self.searchTableView.dataSource = self;
    self.searchTableView.delegate = self;
    [self.view addSubview:self.searchTableView];
    self.statusBarBg.backgroundColor = [UIColor clearColor];
    self.statusBarBg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusBarBg];
    [self.statusBarBg.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0.0].active = YES;
    [self.statusBarBg.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:0.0].active = YES;
    [self.statusBarBg.heightAnchor constraintEqualToConstant:[self statusBarHeight]].active = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.wayfindingStartedYet = NO;
    self.indooratlas.delegate = self;
    [self.indooratlas startUpdatingLocation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = nil;
    self.navigationController.navigationBar.translucent = NO;
    [self hideSearchTable];
    [SVProgressHUD dismiss];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.indooratlas releaseArSession];
    [self.indooratlas stopUpdatingLocation];
    self.indooratlas.delegate = nil;
    [self.arView.session pause];
}

+ (ARConfiguration*)configuration {
    ARWorldTrackingConfiguration* configuration = [[ARWorldTrackingConfiguration alloc] init];
    configuration.planeDetection = ARPlaneDetectionHorizontal;
    configuration.worldAlignment = ARWorldAlignmentGravity;
    return configuration;
}

+ (BOOL)isSupported {
    return [ARWorldTrackingConfiguration isSupported];
}

- (void)updatePois:(NSArray<IAPOI*>*)iapois {
    NSMutableArray* newPois = [NSMutableArray array];
    for (IAPOI* poi in iapois) {
        [newPois addObject:[[ARPOI alloc] initWithPOI:poi session:self.indooratlas.arSession]];
    }
    self.pois = newPois;
}

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region {
    if (region.type == kIARegionTypeFloorPlan) {
        self.floorPlan = region.floorplan;
    } else if (region.type == kIARegionTypeVenue) {
        [SVProgressHUD dismiss];
        [self updatePois:region.venue.pois];
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didExitRegion:(IARegion *)region {
    if (region.type == kIARegionTypeFloorPlan) {
        self.floorPlan = nil;
    } else if (region.type == kIARegionTypeVenue) {
        [self updatePois:nil];
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didUpdateRoute:(IARoute *)route {
    
}

- (void)renderer:(id<SCNSceneRenderer>)renderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time {
    ARFrame* frame = self.arView.session.currentFrame;
    IAARSession* arSession = self.indooratlas.arSession;
    if (frame == nil || arSession == nil) {
        return;
    }
    [arSession setCameraToWorldMatrix:simd_inverse([frame.camera viewMatrixForOrientation:UIInterfaceOrientationPortrait])];
    
    CGFloat scale = 0.5;
    if (self.floorPlan != nil) {
        scale = (self.floorPlan.widthMeters * self.floorPlan.heightMeters) / 50.0;
        scale = MIN(MAX(scale, 0.4), 1.5);
    }
    
    if (arSession.converged == YES) {
        simd_float4x4 matrix = matrix_identity_float4x4;
        if ([arSession.wayfindingTarget updateModelMatrix:&matrix] == YES) {
            self.target.simdWorldTransform = matrix;
            self.target.scale = SCNVector3Make(scale * 1.5, scale * 1.5, scale * 1.5);
            self.target.opacity = distanceFade(self.target.position, self.arView.pointOfView.position);
        }
        
        if ([arSession.wayfindingCompassArrow updateModelMatrix:&matrix] == YES) {
            self.arrow.simdWorldTransform = matrix;
            self.arrow.scale = SCNVector3Make(0.3, 0.3, 0.3);
        }
        
        NSInteger wnum = 0.0;
        for (IAARObject* waypoint in arSession.wayfindingTurnArrows) {
            if ([waypoint updateModelMatrix:&matrix] == YES) {
                if (self.waypoints.count <= wnum) {
                    continue;
                }
                self.waypoints[wnum].simdWorldTransform = matrix;
                self.waypoints[wnum].scale = SCNVector3Make(scale, scale, scale);
                self.waypoints[wnum].opacity = distanceFade(self.waypoints[wnum].position, self.arView.pointOfView.position);
                wnum++;
            }
        }
        
        for (ARPOI* poi in self.pois) {
            if ([poi.object updateModelMatrix:&matrix] == YES
                ) {
                poi.node.simdWorldTransform = matrix;
                poi.node.scale = SCNVector3Make(scale, scale, scale);
                poi.node.opacity = distanceFade(poi.node.position, self.arView.pointOfView.position);
                [poi.node lookAt:self.arView.pointOfView.position up:SCNVector3Make(0.0, 1.0, 0.0) localFront:SCNVector3Make(0.0, 0.0, 1.0)];
            }
        }
    }
    
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    while (self.arView.scene.rootNode.childNodes.count != 0) {
        [self.arView.scene.rootNode.childNodes.firstObject removeFromParentNode];
    }
    IAARSession* arSession = self.indooratlas.arSession;
    if (arSession == nil) {
        return;
    }
    [UIView animateWithDuration:0.25 animations:^{
        switch (frame.camera.trackingState) {
            case ARTrackingStateNormal:
                self.infoLabel.alpha = (arSession.converged ? 0.0 : 1.0);
                break;
            default:
                self.infoLabel.alpha = 1.0;
                break;
        }
    }];
    
    switch (frame.camera.trackingState) {
        case ARTrackingStateNormal:
            break;
        default:
            return;
    }
    
    for (ARAnchor* anchor in frame.anchors) {
        if (![anchor isKindOfClass:[ARPlaneAnchor class]]) {
            continue;
        }
        ARPlaneAnchor* planeAnchor = (ARPlaneAnchor*)anchor;
        if (planeAnchor.alignment != ARPlaneAnchorAlignmentHorizontal) {
            continue;
        }
        [arSession addPlaneWithCenterX:planeAnchor.center.x withCenterY:planeAnchor.center.y withCenterZ:planeAnchor.center.z withExtentX:planeAnchor.extent.x withExtentZ:planeAnchor.extent.z];
    }
    [arSession setPoseMatrix:frame.camera.transform];
    
    if (arSession.converged == YES) {
        simd_float4x4 matrix = matrix_identity_float4x4;

        if ([arSession.wayfindingTarget updateModelMatrix:&matrix] == YES) {
            [self.arView.scene.rootNode addChildNode:self.target];
        }
        
        if ([arSession.wayfindingCompassArrow updateModelMatrix:&matrix] == YES) {
            [self.arView.scene.rootNode addChildNode:self.arrow];
        }
        
        NSInteger wnum = 0;
        for (IAARObject* waypoint in arSession.wayfindingTurnArrows) {
            if ([waypoint updateModelMatrix:&matrix] == YES) {
                if (self.waypoints.count <= wnum) {
                    SCNNode* node = nil;
                    if ([self.waypoints count] > 0) {
                        node = [self.waypoints.firstObject clone];
                    } else {
                        SCNMaterial* outline = [[SCNMaterial alloc] init];
                        outline.diffuse.contents = [UIColor whiteColor];
                        outline.cullMode = SCNCullModeFront;
                        node = [SCNScene sceneNamed:@"Models.scnassets/arrow.obj"].rootNode.childNodes.firstObject;
                        node.geometry.materials = @[outline];
                        SCNNode* base = deepCopyNode(node);
                        base.scale = SCNVector3Make(0.9f, 0.9f, 0.9f);
                        SCNMaterial* material = [[SCNMaterial alloc] init];
                        material.diffuse.contents = [UIColor colorWithRed:95.0f/255.0f green:209.0f/255.0f blue:195.0f/255.0f alpha:1.0f];
                        base.geometry.materials = @[material];
                        [node addChildNode:base];
                    }
                    [self.waypoints addObject:node];
                    assert(self.waypoints.count - 1 == wnum);
                }
                [self.arView.scene.rootNode addChildNode:self.waypoints[wnum]];
                wnum++;
            }
        }
        
        for (ARPOI* poi in self.pois) {
            if (CLCOORDINATES_EQUAL(poi.poi.coordinate, self.wayfindingTarget.coordinate)) {
                continue;
            }
            if (self.floorPlan.floor.level != poi.poi.floor.level) {
                continue;
            }
            if ([poi.object updateModelMatrix:&matrix] == YES) {
                [self.arView.scene.rootNode addChildNode:poi.node];
            }
        }
    }
    
    // Restart wayfinding if we didn't have an active AR session when we started it
    // This is needed for AR wayfinding to start properly as well
    if (!self.wayfindingStartedYet && self.wayfindingTarget != nil) {
        [self.indooratlas stopMonitoringForWayfinding];
        [self.indooratlas startMonitoringForWayfinding:self.wayfindingTarget];
        self.wayfindingStartedYet = YES;
    }
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    [self resetTracking];
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    [self resetTracking];
}

- (void)resetTracking {
    [self.arView.session runWithConfiguration:[[self class] configuration]
            options:ARSessionRunOptionResetTracking|ARSessionRunOptionRemoveExistingAnchors];
}

- (void)startWayfindToDest:(IAWayfindingRequest*)dest {
    self.wayfindingTarget = dest;
    if (dest != nil) {
        [self.indooratlas startMonitoringForWayfinding:dest];
    }
}

- (void)hideSearchTable {
    [UIView animateWithDuration:0.25 animations:^{
        self.searchTableView.alpha = 0.0;
        self.navigationController.navigationBar.backgroundColor = [UIColor clearColor];
        self.statusBarBg.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        if (finished) {
            self.searchTableView.hidden = YES;
        }
    }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.searchBar.text = nil;
    [self.searchBar resignFirstResponder];
    [self hideSearchTable];
    [self startWayfindToDest:nil];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.searchTableView.alpha = 0.0;
    self.searchTableView.hidden = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.searchTableView.alpha = 1.0;
        self.navigationController.navigationBar.backgroundColor = [UIColor colorWithRed:22.0/255.0 green:129.0/255.0 blue:251.0/255.0 alpha:1.0];
        self.statusBarBg.backgroundColor = [UIColor colorWithRed:22.0/255.0 green:129.0/255.0 blue:251.0/255.0 alpha:1.0];
    }];
    [self searchBar:searchBar textDidChange:@""];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"poi.name CONTAINS[c] %@ OR poi.name.length = 0 OR %@.length = 0", [searchText lowercaseString]];
    self.searchDataSource = [self.pois filteredArrayUsingPredicate:predicate];
    [self.searchTableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchDataSource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"SearchCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SearchCell"];
    }
    ARPOI* poi = self.searchDataSource[indexPath.row];
    cell.textLabel.text = poi.poi.name;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self hideSearchTable];
    ARPOI* poi = self.searchDataSource[indexPath.row];
    self.searchBar.text = poi.poi.name;
    [self.searchBar resignFirstResponder];
    [self hideSearchTable];
    IAWayfindingRequest* dest = [[IAWayfindingRequest alloc] init];
    dest.coordinate = poi.poi.coordinate;
    dest.floor = poi.poi.floor.level;
    [self startWayfindToDest:dest];
}

@end
