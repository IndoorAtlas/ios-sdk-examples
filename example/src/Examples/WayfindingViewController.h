//
//  WayfindingViewController.h
//  sdk-examples
//
//  Copyright © 2018 IndoorAtlas. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IndoorAtlas/IndoorAtlas.h"
#import <MapKit/MapKit.h>
#import "AppleMapsOverlayViewController.h"

@interface WayfindingViewController : UIViewController
@property (nonatomic, strong) IALocationManager *locationManager;
@property (strong) MKMapView *map;
@end
