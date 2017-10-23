/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <UIKit/UIKit.h>
#import "IndoorAtlas/IndoorAtlas.h"
#import <MapKit/MapKit.h>

@interface MapOverlay : NSObject <MKOverlay>
- (id)initWithFloorPlan:(IAFloorPlan *)floorPlan andRotatedRect:(CGRect)rotated;
- (MKMapRect)boundingMapRect;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property CLLocationCoordinate2D center;
@property MKMapRect rect;
@end

@interface MapOverlayRenderer : MKOverlayRenderer
@property (nonatomic, strong, readwrite) IAFloorPlan *floorPlan;
@property (strong, readwrite) UIImage *image;
@property CGRect rotated;
@end

@interface AppleMapsOverlayViewController : UIViewController
@property (nonatomic, strong) IALocationManager *locationManager;
@property (strong) MKMapView *map;
@end



