//
//  CalibrationIndicator.h
//  indooratlas-ios-sdk-example
//
//  Created by Seppo Tomperi on 02/05/2017.
//  Copyright © 2017 IndoorAtlas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IndoorAtlas/IALocationManager.h>

@class UINavigationItem;

@interface CalibrationIndicator : NSObject
- (id)initWithNavigationItem:(UINavigationItem *)navigationItem andCalibration:(enum ia_calibration)calibration;
- (void)setCalibration:(enum ia_calibration)calibration;
@end
