/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <IndoorAtlas/IndoorAtlas.h>

extern CGFloat vec3Distance(SCNVector3 a, SCNVector3 b);
extern CGFloat distanceFade(SCNVector3 a, SCNVector3 b);
extern SCNNode* deepCopyNode(SCNNode* node);

#define CLCOORDINATES_EQUAL( coord1, coord2 ) (coord1.latitude == coord2.latitude && coord1.longitude == coord2.longitude)

@interface ARPOI : NSObject
@property (nonatomic, retain) IAARObject* object;
@property (nonatomic, retain) SCNNode* node;
@property (nonatomic, retain) IAPOI* poi;
- (instancetype)initWithPOI:(IAPOI*)poi session:(IAARSession*)session;
@end
