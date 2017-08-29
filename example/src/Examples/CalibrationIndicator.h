/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <Foundation/Foundation.h>
#import <IndoorAtlas/IALocationManager.h>

@class UINavigationItem;

@interface CalibrationIndicator : NSObject
- (id)initWithNavigationItem:(UINavigationItem *)navigationItem andCalibration:(enum ia_calibration)calibration;
- (void)setCalibration:(enum ia_calibration)calibration;
@end
