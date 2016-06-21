//
//  ApiKeys.h
//  indooratlas-ios-sdk
//

#ifndef indooratlas_ios_sdk_ApiKeys_h
#define indooratlas_ios_sdk_ApiKeys_h

// API keys can be generated at <https://app.indooratlas.com/apps>
static NSString *kAPIKey = @"";
static NSString *kAPISecret = @"";

// Floor plan id is same as "FloorplanId" at the <https://app.indooratlas.com/locations>
static NSString *kFloorplanId = @"";

// Beacon ID, major and minor. Also the location of a beacon
// These are for the iBeacon example and require a beacon to work
static NSString *BeaconUUID = @"";
static NSString *BeaconIdentifier = @"";
static NSString *majorId = @"";
static NSString *minorId = @"";
static NSString *latitudeOfBeacon = @"";
static NSString *longitudeOfBeacon = @"";

#endif
