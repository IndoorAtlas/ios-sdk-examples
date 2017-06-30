#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "Examples.h"

#import "AppleMapsViewController.h"
#import "AppleMapsOverlayViewController.h"
#import "ImageViewController.h"
#import "ConsoleViewController.h"
#import "RegionViewController.h"
#import "ShareLocationViewController.h"
#import "BackgroundViewController.h"
#import "GeofenceViewController.h"
#import "LowPowerViewController.h"
#import "OrientationViewController.h"
#import "../ApiKeys.h"

@implementation Examples

+ (NSArray *)loadSections {
    return @[ @"Positioning"];
}

+ (NSArray *)loadDemos {
    NSMutableArray *mapDemos =
    [@[[self newDemo:[AppleMapsViewController class]
         withTitle:@"Apple Maps"
     andDescription:nil],
       [self newDemo:[AppleMapsOverlayViewController class]
         withTitle:@"Apple Maps Overlay"
     andDescription:nil],
       [self newDemo:[ImageViewController class]
         withTitle:@"Image View"
     andDescription:nil],
       [self newDemo:[ConsoleViewController class]
         withTitle:@"Console Prints"
     andDescription:nil],
       [self newDemo:[RegionViewController class]
         withTitle:@"Regions"
     andDescription:nil],
       [self newDemo:[BackgroundViewController class]
         withTitle:@"Background"
     andDescription:nil],
       [self newDemo:[GeofenceViewController class]
         withTitle:@"Geofence"
     andDescription:nil],
       [self newDemo:[LowPowerViewController class]
         withTitle:@"Low-power"
     andDescription:nil],
       [self newDemo:[OrientationViewController class]
         withTitle:@"Orientation"
     andDescription:nil],
      ] mutableCopy];
    
    if ([kPubNubPublishKey length] > 0 && [kPubNubSubscribeKey length] > 0) {
        [mapDemos addObject:[self newDemo:[ShareLocationViewController class]
                                withTitle:@"Share Location"
                           andDescription:nil]];
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
