/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <UIKit/UIKit.h>
#import "IndoorAtlas/IndoorAtlas.h"
#import <MapKit/MapKit.h>

@interface IndoorOutdoorViewController : UIViewController
@property (nonatomic, strong) IALocationManager *IALocationManager;
@property (strong) MKMapView *mapView;
@end

