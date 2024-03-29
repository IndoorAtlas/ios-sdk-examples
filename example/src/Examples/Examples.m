/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "Examples.h"

#import "AppleMapsOverlayViewController.h"
#import "ImageViewController.h"
#import "BackgroundViewController.h"
#import "GeofenceViewController.h"
#import "OrientationViewController.h"
#import "MapViewController.h"
#import "POIViewController.h"
#import "ARViewController.h"
#import "ThirdPartyARViewController.h"
#import "../ApiKeys.h"

@implementation Examples

+ (NSArray *)loadSections {
    return @[ @"Positioning"];
}

+ (NSArray *)loadDemos {
    NSMutableArray *mapDemos =
    [@[[self newDemo:[MapViewController class]
         withTitle:@"Map View"
     andDescription:nil],
       [self newDemo:[ImageViewController class]
         withTitle:@"Image View"
     andDescription:nil],
       [self newDemo:[BackgroundViewController class]
         withTitle:@"Background"
     andDescription:nil],
       [self newDemo:[GeofenceViewController class]
         withTitle:@"Geofence"
     andDescription:nil],
       [self newDemo:[POIViewController class]
         withTitle:@"Point of Interest"
     andDescription:nil],
       [self newDemo:[OrientationViewController class]
         withTitle:@"Orientation"
     andDescription:nil]
      ] mutableCopy];
    
    if (@available(iOS 11.0, *)) {
        [mapDemos addObject:[self newDemo:[ARViewController class] withTitle:@"AR view" andDescription:nil]];
        [mapDemos addObject:[self newDemo:[ThirdPartyARViewController class] withTitle:@"3rd Party AR view" andDescription:nil]];
    }
    
    return @[mapDemos];
}

+ (NSDictionary *)newDemo:(Class) class
                withTitle:(NSString *)title
           andDescription:(NSString *)description {
    return [[NSDictionary alloc] initWithObjectsAndKeys:class, @"controller",
            title, @"title", description, @"description", nil];
}
@end
