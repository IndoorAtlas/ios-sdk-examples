/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import "ARUtils.h"

CGFloat vec3Distance(SCNVector3 a, SCNVector3 b) {
    return hypot(hypot(a.x - b.x, a.y - b.y), a.z - b.z);
}

CGFloat distanceFade(SCNVector3 a, SCNVector3 b) {
    CGFloat FADE_END = 15.0f;
    CGFloat FADE_START = 5.0f;
    CGFloat dis = MAX(vec3Distance(a, b), FADE_START);
    return (FADE_END - MIN(dis - FADE_START, FADE_END)) / FADE_END;
}

SCNNode* deepCopyNode(SCNNode* node) {
    SCNNode* clone = [node clone];
    clone.geometry = [node.geometry copy];
    if (node.geometry != nil) {
        NSMutableArray* clonedMaterials = [NSMutableArray array];
        for (SCNMaterial* m in node.geometry.materials) {
            [clonedMaterials addObject:[m copy]];
        }
        clone.geometry.materials = clonedMaterials;
    }
    return clone;
}

@implementation ARPOI

- (instancetype)initWithPOI:(IAPOI*)poi session:(IAARSession*)session {
    if (self = [super init]) {
        self.poi = poi;
        self.object = [session createPoi:poi.coordinate floorNumber:(int)poi.floor.level heading:0 zOffset:0.75];
        UIImage* image = [UIImage imageNamed:@"Models.scnassets/IA_AR_ad_framed.png"];
        SCNMaterial* material = [SCNMaterial material];
        material.diffuse.contents = image;
        CGFloat bound = MAX(image.size.width, image.size.height);
        self.node = [SCNNode node];
        self.node.geometry = [SCNPlane planeWithWidth:image.size.width / bound height:image.size.height / bound];
        self.node.geometry.materials = @[material];
    }
    return self;
}

@end
