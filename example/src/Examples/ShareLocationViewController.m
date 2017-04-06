#import <IndoorAtlas/IALocationManager.h>
#import <IndoorAtlas/IAResourceManager.h>
#import "ShareLocationViewController.h"
#import "../ApiKeys.h"
#import <PubNub/PubNub.h>

static const CGFloat kCircleAlpha  = 0.2;
static const CGFloat kDotAlpha     = 1.0;
static const CGFloat kCircleRadius = 50.0;
static const CGFloat kMinRadius    = 1.0;
static const CGFloat kDotSizeRatio = 20.0;
static const CGFloat kTextOffset   = 5.0;
static const CGFloat kTimeOutTime  = 5.0;
static const CGFloat kUsernameFontSize = 12.0;
static const CGFloat kLabelBorderSize  = 0.5;
static const CGFloat kScrollViewInset  = 100.0;

static const NSString* kSourceKey   = @"source";
static const NSString* kLocationKey = @"location";
static const NSString* kLatKey      = @"lat";
static const NSString* kLonKey      = @"lon";
static const NSString* kNameKey     = @"name";
static const NSString* kColorKey    = @"color";
static const NSString* kIdKey       = @"id";
static const NSString* kAccuracyKey = @"accuracy";

static NSString* const kChannelNameKey = @"channelName";
static NSString* const kUsernameKey    = @"username";
static NSString* const kUUIDkey        = @"uuid";
static NSString* const kUserColorKey   = @"color";

@interface ShareLocationUser : NSObject
@property (nonatomic, readonly, nonnull) NSString *uuid;
@property (nonatomic, assign) NSInteger color;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UIView *circle;
@property (nonatomic, strong) UILabel *userLabel;
@property (nonatomic, strong) NSDate *timeStamp;
@end

@implementation ShareLocationUser

-(id)initWithUUID:(NSString*) uuid {
    self = [super init];
    if (self) {
        _uuid = uuid;
    }
    return self;
}

@end

@interface ShareLocationViewController () <IALocationManagerDelegate, PNObjectEventListener, UIGestureRecognizerDelegate, UIScrollViewDelegate> {
    id<IAFetchTask> floorPlanFetch;
    id<IAFetchTask> imageFetch;
}

@property (nonatomic, strong) IAFloorPlan *floorPlan;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) IALocationManager *manager;
@property (nonatomic, strong) IAResourceManager *resourceManager;
@property (nonatomic, strong) PubNub *client;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *channelLabel;
@property (nonatomic, strong) NSMutableDictionary *users;
@property (nonatomic, strong) ShareLocationUser *user;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSTimer* timer;
@property (nonatomic, strong) UIActivityIndicatorView* activityIndicator;
@end

@implementation ShareLocationViewController

#pragma mark IALocationManager delegate methods

/**
 * Handle location changes
 */
- (void)indoorLocationManager:(IALocationManager *)manager didUpdateLocations:(NSArray *)locations {
    IALocation* loc = [locations lastObject];
    if (self.floorPlan != nil) {
        [self.user.circle setHidden:NO];
        [self.user.userLabel setHidden:NO];
        NSString* message = [self locationToJSON:loc];
        float radius = 2 * loc.location.horizontalAccuracy * self.floorPlan.meterToPixelConversion;
  
        if (radius < kMinRadius) {
            radius = kMinRadius;
        }
        
        [self updateUserCircle:self.user withRadius:radius];
    
        __weak typeof(self) weakSelf = self;
        
        [weakSelf.client publish:message toChannel: weakSelf.channelLabel.text storeInHistory:NO
              withCompletion:^(PNPublishStatus *status) {
                  if (!status.isError) {
                      NSLog(@"Message %@ published succesfully to channel %@", message, weakSelf.channelLabel.text);
                  }
                  else {
                      NSLog(@"Message publish error %ld (%@)", (long)status.category, status.errorData.information);
                  }
              }];
        
        // The accuracy of coordinate position depends on the placement of floor plan image.
        CGPoint point = [self.floorPlan coordinateToPoint:loc.location.coordinate];
        NSLog(@"position changed to pixel point: %fx%f", point.x, point.y);
        [UIView animateWithDuration:(weakSelf.user.circle.hidden ? 0.0f : 0.35f) animations:^{
            weakSelf.user.circle.center = point;
            [weakSelf updateUserLabelPosition:weakSelf.user withView:weakSelf.view andZoomScale:weakSelf.scrollView.zoomScale];
        }];
    }
}

/**
 * When entering new region the region name is PubNub channel name
 */
-(void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region {
    if (region.type == kIARegionTypeFloorPlan) {
        [[NSUserDefaults standardUserDefaults] setObject:kChannelNameKey forKey:region.identifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.channelLabel setText:region.identifier];
        [self.client subscribeToChannels:@[region.identifier] withPresence:NO];
        [self fetchFloorplanWithId:region.identifier];
    }
}

/**
 * When exiting region the PubNub channel is exited also
 */
-(void)indoorLocationManager:(nonnull IALocationManager*)manager didExitRegion:(nonnull IARegion*)region {
    if (region) {
        [self.client unsubscribeFromPresenceChannels:@[region.identifier]];
    }
}

#pragma mark IndoorAtlas API Usage

/**
 * Fetch floor plan and image with ID
 * These methods are just wrappers around server requests.
 * You will need api key and secret to fetch resources.
 */
- (void)fetchFloorplanWithId:(NSString*)floorplanId {
    [self.activityIndicator startAnimating];
    __weak typeof(self) weakSelf = self;
    if (floorPlanFetch != nil) {
        [floorPlanFetch cancel];
        floorPlanFetch = nil;
    }
    if (imageFetch != nil) {
        [imageFetch cancel];
        imageFetch = nil;
    }
    
    floorPlanFetch = [self.resourceManager fetchFloorPlanWithId:floorplanId andCompletion:^(IAFloorPlan *floorplan, NSError *error) {
        if (error) {
            NSLog(@"Error during floorplan fetch: %@", error);
            return;
        }
        
        NSLog(@"fetched floorplan with id: %@", floorplanId);
        
        imageFetch = [self.resourceManager fetchFloorPlanImageWithUrl:floorplan.imageUrl andCompletion:^(NSData *data, NSError *error) {
            if (error) {
                NSLog(@"Error during floorplan image fetch: %@", error);
                return;
            }
            self.scrollView.zoomScale = 1.0;
            UIImage *image = [UIImage imageWithData:data];
            [self.imageView setImage:image];
            self.imageView.frame = CGRectMake(0, 0, [image size].width, [image size].height);
            [self.scrollView setContentSize:[image size]];
            
            float zoomWidth = self.view.bounds.size.width / self.imageView.image.size.width;
            float zoomHeight = self.view.bounds.size.height / self.imageView.image.size.height;
            
            float zoomScale = MIN(zoomWidth, zoomHeight);
            self.scrollView.zoomScale = self.scrollView.minimumZoomScale = zoomScale;
            [self.scrollView setContentOffset:CGPointMake(0, -kScrollViewInset)];
            [self.activityIndicator stopAnimating];
        }];
        
        weakSelf.floorPlan = floorplan;
    }];
}

/**
 * Authenticate to IndoorAtlas services
 */
- (void)requestLocation {
    // Create IALocationManager and point delegate to receiver
    self.manager = [IALocationManager new];
    self.manager.delegate = self;
    
    // Optionally set initial location
    IALocation *location = [IALocation locationWithFloorPlanId:kFloorplanId];
    self.manager.location = location;
    
    // Create floor plan manager
    self.resourceManager = [IAResourceManager resourceManagerWithLocationManager:self.manager];
    
    // Request location updates
    [self.manager startUpdatingLocation];
}

#pragma mark PNObjectEventListener

/*
 * Show new user or update old user position in the map if user is in same region than we
 */
-(void)client:(PubNub *)client didReceiveMessage:(PNMessageResult *)message {
    if (self.floorPlan) {
        // Check is the message in current region channel
        if ([message.data.channel isEqualToString:message.data.subscription]) {
            // We're not interested about our own messages, only others who are in the same channel
            if (![message.data.publisher isEqualToString:client.uuid] && [message.data.message isKindOfClass:[NSDictionary class]]) {
                NSLog(@"Received message: %@ on channel %@ at %@", message.data.message,
                      message.data.channel, message.data.timetoken);
                NSDictionary *messageDict = (NSDictionary*)message.data.message;
                NSDictionary* locationDict = [messageDict objectForKey:kLocationKey];
                NSDictionary* sourceDict   = [messageDict objectForKey:kSourceKey];
                if (locationDict && sourceDict) {
                    NSString* uuid = [sourceDict objectForKey:kIdKey];
                    NSString* name = [sourceDict objectForKey:kNameKey];
                    NSString* color = [sourceDict objectForKey:kColorKey];
                    
                    NSString* lat = [locationDict objectForKey:kLatKey];
                    NSString* lon = [locationDict objectForKey:kLonKey];
                    NSString* accuracy = [locationDict objectForKey:kAccuracyKey];
                    
                    if (uuid && name && color && lat && lon && accuracy) {
                        ShareLocationUser *user = [self.users objectForKey:uuid];
                        float radius = 2 * [accuracy floatValue] * self.floorPlan.meterToPixelConversion;
                        if (radius < kMinRadius) {
                            radius = kMinRadius;
                        }
                        
                        if (!user) {
                            user = [[ShareLocationUser alloc] initWithUUID:uuid];
                            [self.users setObject:user forKey:uuid];
                            
                            user.dot = [[UIView alloc] init];
                            user.dot.layer.masksToBounds = YES;
                            
                            user.circle = [[UIView alloc] init];
                            user.circle.layer.masksToBounds = YES;
                            [user.circle addSubview:user.dot];
                            [self.imageView addSubview:user.circle];
                            
                            user.userLabel = [UILabel new];
                            user.userLabel.textColor = [self UIColorFromRGB:user.color withAlpha:kDotAlpha];
                            user.userLabel.textAlignment = NSTextAlignmentLeft;
                            user.userLabel.backgroundColor = [UIColor clearColor];
                            user.userLabel.adjustsFontSizeToFitWidth = YES;
                            user.userLabel.numberOfLines = 1;
                            [user.userLabel setFont:[UIFont systemFontOfSize:kUsernameFontSize]];
                            [self.view addSubview:user.userLabel];
                        }
                        [self updateUserCircle:user withRadius:radius];
                        
                        user.username = name;
                        user.coordinate = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);
                        user.color = [color integerValue];
  
                        user.circle.backgroundColor = [self UIColorFromRGB:[color integerValue] withAlpha:kCircleAlpha];
                        user.dot.backgroundColor = [self UIColorFromRGB:[color integerValue] withAlpha:kDotAlpha];
                        user.userLabel.textColor = [self UIColorFromRGB:[color integerValue] withAlpha:kDotAlpha];
                        user.userLabel.text = user.username;
                        [user.userLabel sizeToFit];
   
                        CGPoint point = [self.floorPlan coordinateToPoint:user.coordinate];
                        user.circle.center = point;
                        
                        [self updateUserLabelPosition:user withView:self.view andZoomScale:self.scrollView.zoomScale];
                        
                        user.timeStamp = [NSDate date];
                    }
                }
            }
        }
    }
}

/*
 * Empty implementation since we're not interested about precence events
 */
- (void)client:(PubNub *)client didReceivePresenceEvent:(PNPresenceEventResult *)event {
    NSLog(@"%s: %ld", __PRETTY_FUNCTION__, (long)event.statusCode);
}

/*
 * Empty implementation since we're not interested about status events, only the PNSubscribeOperation
 * is partially handled as an example since we dont use that information anyway
 */
- (void)client:(PubNub *)client didReceiveStatus:(PNStatus *)status {
    NSLog(@"%s: %ld", __PRETTY_FUNCTION__, (long)status.operation);
    __weak typeof(self) weakSelf = self;
    switch (status.operation) {
        case PNSubscribeOperation: {
            if (status.category == PNConnectedCategory || status.category == PNReconnectedCategory) {
                PNSubscribeStatus *subscribeStatus = (PNSubscribeStatus *)status;
                if (subscribeStatus.category == PNConnectedCategory) {
                    [self.client hereNowForChannel:self.channelLabel.text withVerbosity:PNHereNowUUID
                                        completion:^(PNPresenceChannelHereNowResult *result,
                                                     PNErrorStatus *status) {
                                            if (!status) {
                                                NSLog(@"Users in channel %@: %@", weakSelf.channelLabel.text, result.data.occupancy);
                                            }
                                        }];
                }
            }
        } break;
        case PNUnsubscribeOperation: {
        } break;
        case PNPublishOperation: {
        } break;
        case PNHistoryOperation: {
        } break;
        case PNHistoryForChannelsOperation: {
        } break;
        case PNWhereNowOperation: {
        } break;
        case PNHereNowGlobalOperation: {
        } break;
        case PNHereNowForChannelOperation: {
        } break;
        case PNHereNowForChannelGroupOperation: {
        } break;
        case PNHeartbeatOperation: {
        } break;
        case PNSetStateOperation: {
        } break;
        case PNStateForChannelOperation: {
        } break;
        case PNStateForChannelGroupOperation: {
        } break;
        case PNAddChannelsToGroupOperation: {
        } break;
        case PNRemoveChannelsFromGroupOperation: {
        } break;
        case PNChannelGroupsOperation: {
        } break;
        case PNRemoveGroupOperation: {
        } break;
        case PNChannelsForGroupOperation: {
        } break;
        case PNPushNotificationEnabledChannelsOperation: {
        } break;
        case PNAddPushNotificationsOnChannelsOperation: {
        } break;
        case PNRemovePushNotificationsFromChannelsOperation: {
        } break;
        case PNRemoveAllPushNotificationsOperation: {
        } break;
        case PNTimeOperation: {
        } break;
        default: {
        } break;
    }
}

#pragma mark UIViewContoller

/*
 * Cancel the timer and stop requesting location and PubNub messages
 */
-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
    self.resourceManager = nil;
    [self.client unsubscribeFromAll];
}

/*
 * Init UI views, current user, PubNub & IndoorAtlas components
 */
-(void)viewDidLoad {
    [super viewDidLoad];
        
    self.imageView = [UIImageView new];
    self.imageView.frame = self.view.frame;
    self.imageView.backgroundColor = [UIColor whiteColor];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.imageView];
    self.scrollView.delegate = self;
    self.scrollView.bounces = NO;
    self.scrollView.bouncesZoom = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator   = NO;
    self.scrollView.backgroundColor  = [UIColor whiteColor];
    self.scrollView.minimumZoomScale = 0.1;
    self.scrollView.maximumZoomScale = 4.0;
    self.scrollView.contentInset = UIEdgeInsetsMake(kScrollViewInset, kScrollViewInset, kScrollViewInset, kScrollViewInset);
    
    PNConfiguration *configuration = [PNConfiguration configurationWithPublishKey:kPubNubPublishKey
                                                                     subscribeKey:kPubNubSubscribeKey];
    configuration.uuid = [[NSUserDefaults standardUserDefaults] stringForKey:kUUIDkey];
    // PubNub's iOS & Android SDK doesn't generate UUID, so we need to generate it ourself
    if (configuration.uuid.length == 0) {
        NSUUID *UUID = [NSUUID UUID];
        configuration.uuid = [UUID UUIDString];
    }
    self.client = [PubNub clientWithConfiguration:configuration];
    
    [self.client addListener:self];
    
    self.users = [[NSMutableDictionary alloc] init];
    
    self.user = [[ShareLocationUser alloc] initWithUUID:[self.client uuid]];
    self.user.username = [[NSUserDefaults standardUserDefaults] stringForKey:kUsernameKey];
    if (self.user.username.length == 0) {
        self.user.username = @"TestUser";
    }
    
    UIBarButtonItem *buttonSettings = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStylePlain target:self action:@selector(showSettings:)];
    UIBarButtonItem *buttonColor = [[UIBarButtonItem alloc] initWithTitle:@"Color" style:UIBarButtonItemStylePlain target:self action:@selector(setRandomColor:)];
    
    [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:buttonSettings, buttonColor, nil]];
    
    NSNumber *storedColor = [[NSUserDefaults standardUserDefaults] objectForKey:kUserColorKey];
    if (storedColor) {
        self.user.color = [storedColor integerValue];
    } else {
        self.user.color = [self RGBFromUIColor:[self randomColor]];
        [[NSUserDefaults standardUserDefaults] setObject:@(self.user.color) forKey:kUserColorKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    self.user.userLabel = [UILabel new];
    self.user.userLabel.textColor = [self UIColorFromRGB:self.user.color withAlpha:kDotAlpha];
    self.user.userLabel.textAlignment = NSTextAlignmentLeft;
    self.user.userLabel.backgroundColor = [UIColor clearColor];
    self.user.userLabel.text = self.user.username;
    self.user.userLabel.adjustsFontSizeToFitWidth = YES;
    self.user.userLabel.numberOfLines = 1;
    [self.user.userLabel setFont:[UIFont systemFontOfSize:kUsernameFontSize]];
    [self.view addSubview:self.user.userLabel];
    [self.user.userLabel sizeToFit];
    [self.user.userLabel setHidden:YES];

    self.user.dot = [[UIView alloc] initWithFrame:CGRectMake(kCircleRadius/2 - 0.5, kCircleRadius/2 - 0.5, 1, 1)];
    self.user.dot.layer.cornerRadius = 0.5;
    self.user.dot.layer.masksToBounds = YES;
    self.user.dot.backgroundColor = [self UIColorFromRGB:self.user.color withAlpha:kDotAlpha];
    
    self.user.circle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCircleRadius, kCircleRadius)];
    self.user.circle.layer.cornerRadius = kCircleRadius/2;
    self.user.circle.layer.masksToBounds = YES;
    self.user.circle.backgroundColor = [self UIColorFromRGB:self.user.color withAlpha:kCircleAlpha];
    [self.user.circle addSubview:self.user.dot];
    [self.user.circle setHidden:YES];
    [self.imageView addSubview:self.user.circle];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGRect labelFrame = CGRectMake(screenRect.size.width/2, screenRect.size.height/2, screenRect.size.width/2, 20);
    
    labelFrame.origin = CGPointZero;
    
    [self.view addSubview:[self defaultLabelWithText:@"Username" andFrame:labelFrame]];
    
    labelFrame.origin.y += labelFrame.size.height;
    
    self.nameLabel = [self defaultLabelWithText:self.user.username andFrame:labelFrame];
    [self.view addSubview:self.nameLabel];
    
    labelFrame.origin.x += screenRect.size.width / 2;
    labelFrame.origin.y = CGPointZero.y;
    
    [self.view addSubview:[self defaultLabelWithText:@"Channel name" andFrame:labelFrame]];
    
    labelFrame.origin.y += labelFrame.size.height;
    
    NSString *storedChannel = [[NSUserDefaults standardUserDefaults] stringForKey:kChannelNameKey];
    if (storedChannel.length == 0) {
        storedChannel = @"LocTestChannel";
    }
    self.channelLabel = [self defaultLabelWithText:storedChannel andFrame:labelFrame];
    [self.view addSubview:self.channelLabel];
    
    [self requestLocation];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeOut:) userInfo:nil repeats:YES];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.transform = CGAffineTransformMakeScale(1.5, 1.5);
    CGRect frame = self.activityIndicator.frame;
    frame.origin = CGPointMake(screenRect.size.width/2 - frame.size.width/2, screenRect.size.height/2 - frame.size.height/2);
    self.activityIndicator.frame = frame;
    [self.view addSubview:self.activityIndicator];
    [self.activityIndicator startAnimating];
}

/*
 * Create default text label
 */
-(UILabel*) defaultLabelWithText:(NSString*) text andFrame:(CGRect) frame {
    UILabel* label = [[UILabel alloc] initWithFrame:frame];
    label.textColor = [UIColor blackColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor whiteColor];
    label.adjustsFontSizeToFitWidth = YES;
    label.userInteractionEnabled = NO;
    label.layer.borderColor = [UIColor blackColor].CGColor;
    label.layer.borderWidth = kLabelBorderSize;
    label.text = text;
    return label;
}

/*
 * Timer callback for removing old users from the map
 */
- (void)timeOut:(NSTimer*)timer {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate* now = [NSDate date];
    NSMutableArray *oldItemKeys = [NSMutableArray array];
    for (NSString *key in self.users) {
        ShareLocationUser *user = [self.users objectForKey:key];
        NSDateComponents *components = [calendar components:NSCalendarUnitSecond fromDate:user.timeStamp toDate:now options:0];
        if (components.second > kTimeOutTime) {
            [user.userLabel removeFromSuperview];
            [user.circle removeFromSuperview];
            [oldItemKeys addObject:key];
        }
    }
    [self.users removeObjectsForKeys:oldItemKeys];
}

/*
 * Dialog for updating username & channel
 */
-(void)showSettings:(UIBarButtonItem*)sender {
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"Settings"
                                                                              message: @"Change name/channel name"
                                                                       preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = @"Username";
        textField.userInteractionEnabled = NO;
        textField.textAlignment = NSTextAlignmentCenter;
        textField.textColor = [UIColor blackColor];
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.user.username;
        textField.placeholder = @"Username";
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = @"Channel name";
        textField.textAlignment = NSTextAlignmentCenter;
        textField.userInteractionEnabled = NO;
        textField.textColor = [UIColor blackColor];
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.channelLabel.text;
        textField.placeholder = @"Channel name";
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray *textfields = alertController.textFields;
        if (textfields.count == 4) {
            UITextField *nameTextView = textfields[1];
            if (nameTextView.text.length > 0 && ![nameTextView.text isEqualToString:self.user.username]) {
                [self.nameLabel setText:nameTextView.text];
                self.user.username = nameTextView.text;
                self.user.userLabel.text = nameTextView.text;
                [self.user.userLabel sizeToFit];
                [[NSUserDefaults standardUserDefaults] setObject:nameTextView.text forKey:kUsernameKey];
            }
            UITextField *channelTextView = textfields[3];
            if (channelTextView.text.length > 0 && ![channelTextView.text isEqualToString:self.channelLabel.text]) {
                [self.channelLabel setText:channelTextView.text];
                [self.client subscribeToChannels:@[channelTextView.text] withPresence:YES];
                [[NSUserDefaults standardUserDefaults] setObject:channelTextView.text forKey:kChannelNameKey];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

/*
 * Sets new random color for user
 */
-(void)setRandomColor:(UIBarButtonItem*)sender {
    UIColor* color = [self randomColor];
    self.user.color = [self RGBFromUIColor:color];
    self.user.dot.backgroundColor = [self UIColorFromRGB:self.user.color withAlpha:kDotAlpha];
    self.user.circle.backgroundColor = [self UIColorFromRGB:self.user.color withAlpha:kCircleAlpha];
    self.user.userLabel.textColor = [self UIColorFromRGB:self.user.color withAlpha:kDotAlpha];
    
    [[NSUserDefaults standardUserDefaults] setObject:@(self.user.color) forKey:kUserColorKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/*
 * Random color as UIColor
 */
-(UIColor*)randomColor {
    CGFloat red   = arc4random_uniform(255) / 255.0;
    CGFloat green = arc4random_uniform(255) / 255.0;
    CGFloat blue  = arc4random_uniform(255) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:kCircleAlpha];
}

/*
 * Converts android color to UIColor
 */
-(UIColor*)UIColorFromRGB:(NSInteger)rgbValue withAlpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0
                           green:((float)((rgbValue & 0xFF00) >> 8))/255.0
                            blue:((float)(rgbValue & 0xFF))/255.0
                           alpha:alpha];
}

/*
 * Converts UIColor to android color
 */
-(NSInteger)RGBFromUIColor:(UIColor*)color {
    NSInteger integerColor = 0;
    CGFloat red, green, blue, alpha;
    if ([color getRed: &red green: &green blue: &blue alpha: &alpha]) {
        NSUInteger redInt   = (NSUInteger)(red * 255 + 0.5);
        NSUInteger greenInt = (NSUInteger)(green * 255 + 0.5);
        NSUInteger blueInt  = (NSUInteger)(blue * 255 + 0.5);
        integerColor = (redInt << 16) | (greenInt << 8) | blueInt;
    }
    return integerColor;
}

/*
 * Update user label position. We dont want to scale the label as the rest of the map so we 
 * need to update label in correct position
 */
-(void)updateUserLabelPosition:(ShareLocationUser*) user withView:(UIView*) view andZoomScale:(CGFloat) zoomScale {
    float dotSize = (user.dot.frame.size.width/2 * zoomScale);
    CGPoint labelCenter = [[user.circle superview] convertPoint:user.circle.center toView:view];
    labelCenter.x += (user.userLabel.frame.size.width/2 + kTextOffset + dotSize);
    user.userLabel.center = labelCenter;
}

/*
 * Converts IALocation location to JSON which is sent to the PubNub channel
 */
- (NSString*)locationToJSON:(IALocation*) location {
    
    NSDictionary* sourceDict = @{kColorKey : @(self.user.color),
                                 kIdKey    : self.client.uuid,
                                 kNameKey  : self.user.username};
    
    NSDictionary* locationDict = @{kAccuracyKey : @(location.location.horizontalAccuracy),
                                   kLatKey : @(location.location.coordinate.latitude),
                                   kLonKey : @(location.location.coordinate.longitude)};
    
    
    NSDictionary* dict = @{kSourceKey   : sourceDict,
                           kLocationKey : locationDict};
    
    NSString* json = @"";
    NSError* error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (!error) {
        json = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
    } else {
        NSLog(@"JSON creating error: %@", [error localizedDescription]);
    }
    
    return json;
}

/*
 * Update user circle to match accuracy received from JSON message.
 * Also update the dot size because so its shown correctly in the map
 */
-(void)updateUserCircle:(ShareLocationUser*) user withRadius:(CGFloat) radius {
    CGRect frame = user.circle.frame;
    frame.size.width = radius;
    frame.size.height = radius;
    user.circle.frame = frame;
    user.circle.layer.cornerRadius = radius/2;
    
    CGFloat dotRadius = radius / kDotSizeRatio;
    user.dot.frame = CGRectMake(0, 0, dotRadius, dotRadius);
    user.dot.center = CGPointMake(radius/2, radius/2);
    user.dot.layer.cornerRadius = dotRadius/2;
}

# pragma mark UIScrollViewDelegate

-(UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateUserLabelPosition:self.user withView:self.view andZoomScale:self.scrollView.zoomScale];
    for (NSString *key in self.users) {
        [self updateUserLabelPosition:[self.users objectForKey:key] withView:self.view andZoomScale:self.scrollView.zoomScale];
    }
}

-(void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self updateUserLabelPosition:self.user withView:self.view andZoomScale:self.scrollView.zoomScale];
    for (NSString *key in self.users) {
        [self updateUserLabelPosition:[self.users objectForKey:key] withView:self.view andZoomScale:self.scrollView.zoomScale];
    }
}

@end
