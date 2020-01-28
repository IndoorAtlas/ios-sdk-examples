/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <IndoorAtlas/IALocationManager.h>
#import "POIViewController.h"

@interface MapViewController () <IALocationManagerDelegate, MKMapViewDelegate>
@end

@interface POIAnnotation : MKPointAnnotation
@property (nonatomic, assign) NSInteger floor;
@end

@implementation POIAnnotation
@end

@interface POIViewController () <IALocationManagerDelegate>
@property (nonatomic, strong) MKPolyline *polyOverlay;
@property (nonatomic, strong) NSMutableArray<MKPointAnnotation*> *annotations;
@property (nonatomic, strong) IAVenue *venue;
@end

@implementation POIViewController

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[POIAnnotation class]]) {
        static NSString *identifier = @"reusable annotation";
        MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
        
        if (!view) {
            view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
            view.canShowCallout = true;
        }
        
        view.annotation = annotation;
        view.leftCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        return view;
    }
    return [super mapView:mapView viewForAnnotation:annotation];
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    IAWayfindingRequest *request = [IAWayfindingRequest new];
    request.coordinate = view.annotation.coordinate;
    request.floor = ((POIAnnotation*)view.annotation).floor;
    [self.locationManager startMonitoringForWayfinding:request];
}

#pragma mark IALocationManagerDelegate methods

- (void)removeAnnotations
{
    if (self.annotations) {
        [self.mapView removeAnnotations:self.annotations];
        self.annotations = nil;
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didEnterRegion:(IARegion *)region
{
    [super indoorLocationManager:manager didEnterRegion:region];

    if (region.type == kIARegionTypeFloorPlan) {
        [self removeAnnotations];
        self.annotations = [NSMutableArray array];
        for (IAPOI *poi in self.venue.pois) {
            if (region.floorplan.floor && poi.floor.level != region.floorplan.floor.level)
                continue;

            POIAnnotation *point = [POIAnnotation new];
            point.title = poi.name;
            point.subtitle = poi.description;
            point.coordinate = poi.coordinate;
            point.floor = poi.floor.level;
            [self.annotations addObject:point];
        }
        [self.mapView addAnnotations:self.annotations];
    } else if (region.type == kIARegionTypeVenue) {
        self.venue = region.venue;
    }
}

- (void)indoorLocationManager:(IALocationManager *)manager didExitRegion:(IARegion *)region
{
    [super indoorLocationManager:manager didExitRegion:region];
    
    if (region.type != kIARegionTypeFloorPlan && region.type != kIARegionTypeVenue)
        return;
    
    [self removeAnnotations];
    
    if (region.type == kIARegionTypeVenue)
        self.venue = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self removeAnnotations];
    [super viewWillDisappear:animated];
    self.venue = nil;
}

@end
