#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "Examples.h"

#import "AppleMapsViewController.h"
#import "AppleMapsOverlayViewController.h"
#import "ImageViewController.h"
#import "ConsoleViewController.h"

@implementation Examples

+ (NSArray *)loadSections {
  return @[ @"Positioning"];
}

+ (NSArray *)loadDemos {
  NSArray *mapDemos =
  @[[self newDemo:[AppleMapsViewController class]
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
  ];

  return @[mapDemos];
}

+ (NSDictionary *)newDemo:(Class) class
                withTitle:(NSString *)title
           andDescription:(NSString *)description {
  return [[NSDictionary alloc] initWithObjectsAndKeys:class, @"controller",
          title, @"title", description, @"description", nil];
}
@end
