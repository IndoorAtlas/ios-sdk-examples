/**
 * IndoorAtlas SDK positioning example
 * Copyright © IndoorAtlas.
 */

#import "PaddingLabel.h"

@implementation PaddingLabel

- (void)setup {
    self.leftInset = 10.0f;
    self.topInset = 10.0f;
}

- (id)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect {
    UIEdgeInsets insets = UIEdgeInsetsMake(self.topInset, self.leftInset, self.bottomInset, self.rightInset);
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}

- (CGSize)intrinsicContentSize {
    CGSize contentSize = [super intrinsicContentSize];
    contentSize.height += self.topInset + self.bottomInset;
    contentSize.width += self.leftInset + self.rightInset;
    return contentSize;
}

@end
