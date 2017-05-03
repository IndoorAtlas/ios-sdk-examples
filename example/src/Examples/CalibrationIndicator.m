//
//  CalibrationIndicator.m
//  indooratlas-ios-sdk-example
//
//  Created by Seppo Tomperi on 02/05/2017.
//  Copyright © 2017 IndoorAtlas. All rights reserved.
//

#import "CalibrationIndicator.h"
#import "UIKit/UIKit.h"

@interface CalibrationIndicator()
@property (nonatomic, strong) UINavigationItem *navigationItem;
@end

@implementation CalibrationIndicator

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class CalibrationIndicator. Use initWithNavigationItem:andCalibration:"
                                 userInfo:nil];
    return nil;
}

- (id)initWithNavigationItem:(UINavigationItem *)navigationItem andCalibration:(enum ia_calibration)calibration
{
    self = [super init];

    if(self) {
        _navigationItem = navigationItem;
        [self setCalibration:calibration];
    }
    return self;
}

- (void)showCalibrationHelp
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"This is the magnetic calibration indicator"
                                                    message:@"Rotate your device until the calibration indicator is green. Usually the best way to calibrate is to calmly turn the device display to face the floor and then back up."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)setCalibration:(enum ia_calibration)calibration
{
    UIBarButtonItem *rotate = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(showCalibrationHelp)];

    switch(calibration) {
        case kIACalibrationPoor:
            [rotate setTintColor:[UIColor redColor]];
            break;

        // Although this is called good, don't settle for this level in your app.
        // Aim to have excellent calibration.
        case kIACalibrationGood:
            [rotate setTintColor:[UIColor yellowColor]];
            break;

        // Excellent calibration is often much better than plain good.
        // In your application logic, always aim to have excellent calibration.
        case kIACalibrationExcellent:
            [rotate setTintColor:[UIColor greenColor]];
            break;
    }
    [self.navigationItem setRightBarButtonItem:rotate];
}

@end
