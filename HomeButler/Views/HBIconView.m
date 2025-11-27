#import "HBIconView.h"

@implementation HBIconView

- (instancetype)initWithIconType:(HBIconType)iconType {
    return [self initWithIconType:iconType color:[UIColor whiteColor]];
}

- (instancetype)initWithIconType:(HBIconType)iconType color:(UIColor *)color {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _iconType = iconType;
        _iconColor = color;
        _iconInset = 4.0;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

- (void)setIconType:(HBIconType)iconType {
    _iconType = iconType;
    [self setNeedsDisplay];
}

- (void)setIconColor:(UIColor *)iconColor {
    _iconColor = iconColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;

    CGRect iconRect = CGRectInset(rect, self.iconInset, self.iconInset);

    [self.iconColor setStroke];

    UIBezierPath *path = [self pathForIconType:self.iconType inRect:iconRect];
    if (path) {
        path.lineWidth = 2.0;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [path stroke];
    }
}

- (UIBezierPath *)pathForIconType:(HBIconType)iconType inRect:(CGRect)rect {
    switch (iconType) {
        case HBIconTypeHouse:
            return [self housePathInRect:rect];
        case HBIconTypeLivingRoom:
            return [self livingRoomPathInRect:rect];
        case HBIconTypeKitchen:
            return [self kitchenPathInRect:rect];
        case HBIconTypeBathTub:
            return [self bathTubPathInRect:rect];
        case HBIconTypeBed:
            return [self bedPathInRect:rect];
        case HBIconTypeGarage:
            return [self garagePathInRect:rect];
        case HBIconTypeWork:
            return [self workPathInRect:rect];
        case HBIconTypeBabyCrib:
            return [self babyCribPathInRect:rect];
        case HBIconTypeGear:
            return [self gearPathInRect:rect];
        case HBIconTypePlus:
            return [self plusPathInRect:rect];
        case HBIconTypePencil:
            return [self pencilPathInRect:rect];
        case HBIconTypeSun:
            return [self sunPathInRect:rect];
        case HBIconTypeCloud:
            return [self cloudPathInRect:rect];
        case HBIconTypeRain:
            return [self rainPathInRect:rect];
        case HBIconTypeSnow:
            return [self snowPathInRect:rect];
        case HBIconTypeStorm:
            return [self stormPathInRect:rect];
        case HBIconTypePartlyCloudy:
            return [self partlyCloudyPathInRect:rect];
        default:
            return nil;
    }
}

#pragma mark - Icon Paths

- (UIBezierPath *)housePathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // House outline: roof peak to walls
    [path moveToPoint:CGPointMake(x, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x + w * 0.5, y)];
    [path addLineToPoint:CGPointMake(x + w, y + h * 0.4)];

    // Walls
    [path moveToPoint:CGPointMake(x + w * 0.15, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x + w * 0.15, y + h)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, y + h)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, y + h * 0.4)];

    // Door
    [path moveToPoint:CGPointMake(x + w * 0.4, y + h)];
    [path addLineToPoint:CGPointMake(x + w * 0.4, y + h * 0.6)];
    [path addLineToPoint:CGPointMake(x + w * 0.6, y + h * 0.6)];
    [path addLineToPoint:CGPointMake(x + w * 0.6, y + h)];

    return path;
}

- (UIBezierPath *)livingRoomPathInRect:(CGRect)rect {
    // Couch/sofa outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Sofa base outline
    [path moveToPoint:CGPointMake(x, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w, y + h * 0.4)];

    // Back rest
    [path moveToPoint:CGPointMake(x + w * 0.1, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x + w * 0.1, y + h * 0.15)];
    [path addLineToPoint:CGPointMake(x + w * 0.9, y + h * 0.15)];
    [path addLineToPoint:CGPointMake(x + w * 0.9, y + h * 0.4)];

    // Arm rests
    [path moveToPoint:CGPointMake(x, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x, y + h * 0.2)];
    [path moveToPoint:CGPointMake(x + w, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x + w, y + h * 0.2)];

    // Legs
    [path moveToPoint:CGPointMake(x + w * 0.15, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w * 0.15, y + h)];
    [path moveToPoint:CGPointMake(x + w * 0.85, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, y + h)];

    return path;
}

- (UIBezierPath *)kitchenPathInRect:(CGRect)rect {
    // Fork and knife outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Fork tines (3 vertical lines)
    [path moveToPoint:CGPointMake(x + w * 0.15, y)];
    [path addLineToPoint:CGPointMake(x + w * 0.15, y + h * 0.35)];
    [path moveToPoint:CGPointMake(x + w * 0.25, y)];
    [path addLineToPoint:CGPointMake(x + w * 0.25, y + h * 0.35)];
    [path moveToPoint:CGPointMake(x + w * 0.35, y)];
    [path addLineToPoint:CGPointMake(x + w * 0.35, y + h * 0.35)];

    // Fork handle
    [path moveToPoint:CGPointMake(x + w * 0.15, y + h * 0.35)];
    [path addLineToPoint:CGPointMake(x + w * 0.35, y + h * 0.35)];
    [path moveToPoint:CGPointMake(x + w * 0.25, y + h * 0.35)];
    [path addLineToPoint:CGPointMake(x + w * 0.25, y + h)];

    // Knife blade and handle
    [path moveToPoint:CGPointMake(x + w * 0.65, y)];
    [path addLineToPoint:CGPointMake(x + w * 0.75, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x + w * 0.75, y + h)];
    [path moveToPoint:CGPointMake(x + w * 0.65, y)];
    [path addLineToPoint:CGPointMake(x + w * 0.65, y + h * 0.4)];
    [path addLineToPoint:CGPointMake(x + w * 0.75, y + h * 0.4)];

    return path;
}

- (UIBezierPath *)bathTubPathInRect:(CGRect)rect {
    // Bathtub outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Tub body outline
    [path moveToPoint:CGPointMake(x, y + h * 0.35)];
    [path addLineToPoint:CGPointMake(x, y + h * 0.75)];
    [path addCurveToPoint:CGPointMake(x + w * 0.15, y + h * 0.85)
            controlPoint1:CGPointMake(x, y + h * 0.82)
            controlPoint2:CGPointMake(x + w * 0.07, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, y + h * 0.85)];
    [path addCurveToPoint:CGPointMake(x + w, y + h * 0.75)
            controlPoint1:CGPointMake(x + w * 0.93, y + h * 0.85)
            controlPoint2:CGPointMake(x + w, y + h * 0.82)];
    [path addLineToPoint:CGPointMake(x + w, y + h * 0.35)];
    [path addLineToPoint:CGPointMake(x, y + h * 0.35)];

    // Faucet
    [path moveToPoint:CGPointMake(x + w * 0.15, y + h * 0.35)];
    [path addLineToPoint:CGPointMake(x + w * 0.15, y + h * 0.15)];
    [path addLineToPoint:CGPointMake(x + w * 0.25, y + h * 0.15)];
    [path addLineToPoint:CGPointMake(x + w * 0.25, y + h * 0.25)];

    // Legs
    [path moveToPoint:CGPointMake(x + w * 0.15, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w * 0.15, y + h)];
    [path moveToPoint:CGPointMake(x + w * 0.85, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, y + h)];

    return path;
}

- (UIBezierPath *)bedPathInRect:(CGRect)rect {
    // Bed outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Headboard
    [path moveToPoint:CGPointMake(x, y + h * 0.15)];
    [path addLineToPoint:CGPointMake(x, y + h * 0.55)];
    [path moveToPoint:CGPointMake(x, y + h * 0.15)];
    [path addLineToPoint:CGPointMake(x + w * 0.25, y + h * 0.15)];
    [path addLineToPoint:CGPointMake(x + w * 0.25, y + h * 0.55)];

    // Mattress/bed frame
    [path moveToPoint:CGPointMake(x, y + h * 0.55)];
    [path addLineToPoint:CGPointMake(x + w, y + h * 0.55)];
    [path addLineToPoint:CGPointMake(x + w, y + h * 0.75)];
    [path addLineToPoint:CGPointMake(x, y + h * 0.75)];
    [path addLineToPoint:CGPointMake(x, y + h * 0.55)];

    // Pillow
    [path moveToPoint:CGPointMake(x + w * 0.05, y + h * 0.35)];
    [path addLineToPoint:CGPointMake(x + w * 0.2, y + h * 0.35)];
    [path addLineToPoint:CGPointMake(x + w * 0.2, y + h * 0.5)];
    [path addLineToPoint:CGPointMake(x + w * 0.05, y + h * 0.5)];
    [path closePath];

    // Legs
    [path moveToPoint:CGPointMake(x + w * 0.05, y + h * 0.75)];
    [path addLineToPoint:CGPointMake(x + w * 0.05, y + h)];
    [path moveToPoint:CGPointMake(x + w * 0.95, y + h * 0.75)];
    [path addLineToPoint:CGPointMake(x + w * 0.95, y + h)];

    return path;
}

- (UIBezierPath *)garagePathInRect:(CGRect)rect {
    // Car outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Car body outline
    [path moveToPoint:CGPointMake(x + w * 0.05, y + h * 0.5)];
    [path addLineToPoint:CGPointMake(x + w * 0.05, y + h * 0.75)];
    [path addLineToPoint:CGPointMake(x + w * 0.95, y + h * 0.75)];
    [path addLineToPoint:CGPointMake(x + w * 0.95, y + h * 0.5)];

    // Cabin/roof
    [path moveToPoint:CGPointMake(x + w * 0.2, y + h * 0.5)];
    [path addLineToPoint:CGPointMake(x + w * 0.3, y + h * 0.2)];
    [path addLineToPoint:CGPointMake(x + w * 0.7, y + h * 0.2)];
    [path addLineToPoint:CGPointMake(x + w * 0.8, y + h * 0.5)];

    // Wheels (circles)
    CGFloat wheelRadius = w * 0.1;
    [path moveToPoint:CGPointMake(x + w * 0.25 + wheelRadius, y + h * 0.8)];
    [path addArcWithCenter:CGPointMake(x + w * 0.25, y + h * 0.8) radius:wheelRadius startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    [path moveToPoint:CGPointMake(x + w * 0.75 + wheelRadius, y + h * 0.8)];
    [path addArcWithCenter:CGPointMake(x + w * 0.75, y + h * 0.8) radius:wheelRadius startAngle:0 endAngle:M_PI * 2 clockwise:YES];

    return path;
}

- (UIBezierPath *)workPathInRect:(CGRect)rect {
    // Briefcase outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Main body outline
    CGFloat r = w * 0.08;
    [path moveToPoint:CGPointMake(x + r, y + h * 0.3)];
    [path addLineToPoint:CGPointMake(x + w - r, y + h * 0.3)];
    [path addArcWithCenter:CGPointMake(x + w - r, y + h * 0.3 + r) radius:r startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [path addLineToPoint:CGPointMake(x + w, y + h - r)];
    [path addArcWithCenter:CGPointMake(x + w - r, y + h - r) radius:r startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [path addLineToPoint:CGPointMake(x + r, y + h)];
    [path addArcWithCenter:CGPointMake(x + r, y + h - r) radius:r startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    [path addLineToPoint:CGPointMake(x, y + h * 0.3 + r)];
    [path addArcWithCenter:CGPointMake(x + r, y + h * 0.3 + r) radius:r startAngle:M_PI endAngle:-M_PI_2 clockwise:YES];

    // Handle
    [path moveToPoint:CGPointMake(x + w * 0.35, y + h * 0.3)];
    [path addLineToPoint:CGPointMake(x + w * 0.35, y + h * 0.12)];
    [path addLineToPoint:CGPointMake(x + w * 0.65, y + h * 0.12)];
    [path addLineToPoint:CGPointMake(x + w * 0.65, y + h * 0.3)];

    // Center line
    [path moveToPoint:CGPointMake(x + w * 0.5, y + h * 0.3)];
    [path addLineToPoint:CGPointMake(x + w * 0.5, y + h)];

    return path;
}

- (UIBezierPath *)babyCribPathInRect:(CGRect)rect {
    // Baby crib outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Left leg
    [path moveToPoint:CGPointMake(x + w * 0.1, y + h * 0.1)];
    [path addLineToPoint:CGPointMake(x + w * 0.1, y + h)];

    // Right leg
    [path moveToPoint:CGPointMake(x + w * 0.9, y + h * 0.1)];
    [path addLineToPoint:CGPointMake(x + w * 0.9, y + h)];

    // Top rail
    [path moveToPoint:CGPointMake(x + w * 0.1, y + h * 0.2)];
    [path addLineToPoint:CGPointMake(x + w * 0.9, y + h * 0.2)];

    // Bottom rail
    [path moveToPoint:CGPointMake(x + w * 0.1, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w * 0.9, y + h * 0.85)];

    // Vertical bars
    CGFloat barSpacing = w * 0.16;
    for (CGFloat bx = x + w * 0.26; bx < x + w * 0.85; bx += barSpacing) {
        [path moveToPoint:CGPointMake(bx, y + h * 0.2)];
        [path addLineToPoint:CGPointMake(bx, y + h * 0.85)];
    }

    return path;
}

- (UIBezierPath *)gearPathInRect:(CGRect)rect {
    // Gear outline
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat cx = rect.origin.x + w * 0.5;
    CGFloat cy = rect.origin.y + h * 0.5;
    CGFloat outerRadius = MIN(w, h) * 0.48;
    CGFloat innerRadius = outerRadius * 0.65;
    CGFloat toothDepth = outerRadius * 0.35;
    NSInteger numTeeth = 8;

    // Create gear outline with teeth
    for (NSInteger i = 0; i < numTeeth; i++) {
        CGFloat angle1 = (2 * M_PI * i) / numTeeth;
        CGFloat angle2 = (2 * M_PI * (i + 0.3)) / numTeeth;
        CGFloat angle3 = (2 * M_PI * (i + 0.5)) / numTeeth;
        CGFloat angle4 = (2 * M_PI * (i + 0.7)) / numTeeth;

        CGPoint p1 = CGPointMake(cx + innerRadius * cos(angle1), cy + innerRadius * sin(angle1));
        CGPoint p2 = CGPointMake(cx + (innerRadius + toothDepth) * cos(angle2), cy + (innerRadius + toothDepth) * sin(angle2));
        CGPoint p3 = CGPointMake(cx + (innerRadius + toothDepth) * cos(angle3), cy + (innerRadius + toothDepth) * sin(angle3));
        CGPoint p4 = CGPointMake(cx + innerRadius * cos(angle4), cy + innerRadius * sin(angle4));

        if (i == 0) {
            [path moveToPoint:p1];
        } else {
            [path addLineToPoint:p1];
        }
        [path addLineToPoint:p2];
        [path addLineToPoint:p3];
        [path addLineToPoint:p4];
    }
    [path closePath];

    // Center hole circle
    CGFloat holeRadius = innerRadius * 0.45;
    [path moveToPoint:CGPointMake(cx + holeRadius, cy)];
    [path addArcWithCenter:CGPointMake(cx, cy) radius:holeRadius startAngle:0 endAngle:M_PI * 2 clockwise:YES];

    return path;
}

- (UIBezierPath *)plusPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;
    CGFloat thickness = MIN(w, h) * 0.25;

    // Horizontal bar
    [path appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(x, y + (h - thickness) / 2, w, thickness)]];

    // Vertical bar
    [path appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(x + (w - thickness) / 2, y, thickness, h)]];

    return path;
}

- (UIBezierPath *)pencilPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Pencil shape (diagonal)
    [path moveToPoint:CGPointMake(x + w * 0.15, y + h * 0.85)];
    [path addLineToPoint:CGPointMake(x + w * 0.0, y + h * 1.0)];
    [path addLineToPoint:CGPointMake(x + w * 0.15, y + h * 0.7)];
    [path addLineToPoint:CGPointMake(x + w * 0.75, y + h * 0.1)];
    [path addLineToPoint:CGPointMake(x + w * 0.9, y + h * 0.1)];
    [path addLineToPoint:CGPointMake(x + w * 0.9, y + h * 0.25)];
    [path addLineToPoint:CGPointMake(x + w * 0.3, y + h * 0.85)];
    [path closePath];

    return path;
}

#pragma mark - Weather Icon Paths

- (UIBezierPath *)sunPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat cx = rect.origin.x + w * 0.5;
    CGFloat cy = rect.origin.y + h * 0.5;
    CGFloat sunRadius = MIN(w, h) * 0.25;
    CGFloat rayLength = MIN(w, h) * 0.18;
    CGFloat rayStart = sunRadius + MIN(w, h) * 0.05;

    // Sun circle
    [path moveToPoint:CGPointMake(cx + sunRadius, cy)];
    [path addArcWithCenter:CGPointMake(cx, cy) radius:sunRadius startAngle:0 endAngle:M_PI * 2 clockwise:YES];

    // Sun rays (8 rays)
    for (int i = 0; i < 8; i++) {
        CGFloat angle = (M_PI * 2 * i) / 8;
        CGFloat startX = cx + rayStart * cos(angle);
        CGFloat startY = cy + rayStart * sin(angle);
        CGFloat endX = cx + (rayStart + rayLength) * cos(angle);
        CGFloat endY = cy + (rayStart + rayLength) * sin(angle);
        [path moveToPoint:CGPointMake(startX, startY)];
        [path addLineToPoint:CGPointMake(endX, endY)];
    }

    return path;
}

- (UIBezierPath *)cloudPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Cloud shape using arcs
    CGFloat baseY = y + h * 0.65;

    // Bottom flat line
    [path moveToPoint:CGPointMake(x + w * 0.15, baseY)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, baseY)];

    // Right bump
    [path addArcWithCenter:CGPointMake(x + w * 0.75, baseY - h * 0.12) radius:h * 0.18 startAngle:M_PI_2 endAngle:-M_PI_2 clockwise:NO];

    // Top right bump
    [path addArcWithCenter:CGPointMake(x + w * 0.55, baseY - h * 0.28) radius:h * 0.22 startAngle:0 endAngle:-M_PI clockwise:NO];

    // Top left bump
    [path addArcWithCenter:CGPointMake(x + w * 0.35, baseY - h * 0.2) radius:h * 0.2 startAngle:0 endAngle:-M_PI clockwise:NO];

    // Left side
    [path addArcWithCenter:CGPointMake(x + w * 0.22, baseY - h * 0.08) radius:h * 0.15 startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:NO];

    return path;
}

- (UIBezierPath *)rainPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Smaller cloud at top
    CGFloat cloudY = y + h * 0.35;
    CGFloat cloudScale = 0.7;

    [path moveToPoint:CGPointMake(x + w * 0.15, cloudY)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, cloudY)];
    [path addArcWithCenter:CGPointMake(x + w * 0.75, cloudY - h * 0.08 * cloudScale) radius:h * 0.12 * cloudScale startAngle:M_PI_2 endAngle:-M_PI_2 clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.55, cloudY - h * 0.18 * cloudScale) radius:h * 0.15 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.35, cloudY - h * 0.12 * cloudScale) radius:h * 0.13 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.22, cloudY - h * 0.05 * cloudScale) radius:h * 0.1 * cloudScale startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:NO];

    // Rain drops
    CGFloat dropStartY = cloudY + h * 0.1;
    CGFloat dropLength = h * 0.15;

    [path moveToPoint:CGPointMake(x + w * 0.25, dropStartY)];
    [path addLineToPoint:CGPointMake(x + w * 0.2, dropStartY + dropLength)];

    [path moveToPoint:CGPointMake(x + w * 0.45, dropStartY)];
    [path addLineToPoint:CGPointMake(x + w * 0.4, dropStartY + dropLength)];

    [path moveToPoint:CGPointMake(x + w * 0.65, dropStartY)];
    [path addLineToPoint:CGPointMake(x + w * 0.6, dropStartY + dropLength)];

    [path moveToPoint:CGPointMake(x + w * 0.35, dropStartY + dropLength * 0.6)];
    [path addLineToPoint:CGPointMake(x + w * 0.3, dropStartY + dropLength * 1.6)];

    [path moveToPoint:CGPointMake(x + w * 0.55, dropStartY + dropLength * 0.6)];
    [path addLineToPoint:CGPointMake(x + w * 0.5, dropStartY + dropLength * 1.6)];

    return path;
}

- (UIBezierPath *)snowPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Smaller cloud at top
    CGFloat cloudY = y + h * 0.35;
    CGFloat cloudScale = 0.7;

    [path moveToPoint:CGPointMake(x + w * 0.15, cloudY)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, cloudY)];
    [path addArcWithCenter:CGPointMake(x + w * 0.75, cloudY - h * 0.08 * cloudScale) radius:h * 0.12 * cloudScale startAngle:M_PI_2 endAngle:-M_PI_2 clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.55, cloudY - h * 0.18 * cloudScale) radius:h * 0.15 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.35, cloudY - h * 0.12 * cloudScale) radius:h * 0.13 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.22, cloudY - h * 0.05 * cloudScale) radius:h * 0.1 * cloudScale startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:NO];

    // Snowflakes (small asterisks)
    CGFloat flakeSize = h * 0.06;
    CGFloat flakeY1 = cloudY + h * 0.2;
    CGFloat flakeY2 = cloudY + h * 0.45;

    // Draw snowflake helper
    void (^drawFlake)(CGFloat, CGFloat) = ^(CGFloat fx, CGFloat fy) {
        for (int i = 0; i < 3; i++) {
            CGFloat angle = (M_PI * i) / 3;
            [path moveToPoint:CGPointMake(fx - flakeSize * cos(angle), fy - flakeSize * sin(angle))];
            [path addLineToPoint:CGPointMake(fx + flakeSize * cos(angle), fy + flakeSize * sin(angle))];
        }
    };

    drawFlake(x + w * 0.25, flakeY1);
    drawFlake(x + w * 0.5, flakeY1);
    drawFlake(x + w * 0.75, flakeY1);
    drawFlake(x + w * 0.35, flakeY2);
    drawFlake(x + w * 0.65, flakeY2);

    return path;
}

- (UIBezierPath *)stormPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Cloud at top
    CGFloat cloudY = y + h * 0.35;
    CGFloat cloudScale = 0.7;

    [path moveToPoint:CGPointMake(x + w * 0.15, cloudY)];
    [path addLineToPoint:CGPointMake(x + w * 0.85, cloudY)];
    [path addArcWithCenter:CGPointMake(x + w * 0.75, cloudY - h * 0.08 * cloudScale) radius:h * 0.12 * cloudScale startAngle:M_PI_2 endAngle:-M_PI_2 clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.55, cloudY - h * 0.18 * cloudScale) radius:h * 0.15 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.35, cloudY - h * 0.12 * cloudScale) radius:h * 0.13 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.22, cloudY - h * 0.05 * cloudScale) radius:h * 0.1 * cloudScale startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:NO];

    // Lightning bolt
    [path moveToPoint:CGPointMake(x + w * 0.55, cloudY + h * 0.05)];
    [path addLineToPoint:CGPointMake(x + w * 0.4, cloudY + h * 0.3)];
    [path addLineToPoint:CGPointMake(x + w * 0.5, cloudY + h * 0.3)];
    [path addLineToPoint:CGPointMake(x + w * 0.35, cloudY + h * 0.55)];
    [path addLineToPoint:CGPointMake(x + w * 0.48, cloudY + h * 0.35)];
    [path addLineToPoint:CGPointMake(x + w * 0.38, cloudY + h * 0.35)];
    [path closePath];

    return path;
}

- (UIBezierPath *)partlyCloudyPathInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;

    // Sun (partial, behind cloud)
    CGFloat sunCx = x + w * 0.7;
    CGFloat sunCy = y + h * 0.3;
    CGFloat sunRadius = MIN(w, h) * 0.18;

    // Sun circle (partial arc visible)
    [path addArcWithCenter:CGPointMake(sunCx, sunCy) radius:sunRadius startAngle:-M_PI * 0.3 endAngle:M_PI * 0.8 clockwise:YES];

    // Sun rays (only upper right ones)
    CGFloat rayLength = MIN(w, h) * 0.12;
    CGFloat rayStart = sunRadius + MIN(w, h) * 0.03;
    for (int i = 0; i < 4; i++) {
        CGFloat angle = -M_PI * 0.2 + (M_PI * 0.8 * i) / 3;
        CGFloat startX = sunCx + rayStart * cos(angle);
        CGFloat startY = sunCy + rayStart * sin(angle);
        CGFloat endX = sunCx + (rayStart + rayLength) * cos(angle);
        CGFloat endY = sunCy + (rayStart + rayLength) * sin(angle);
        [path moveToPoint:CGPointMake(startX, startY)];
        [path addLineToPoint:CGPointMake(endX, endY)];
    }

    // Cloud in front (lower left)
    CGFloat cloudY = y + h * 0.7;
    CGFloat cloudScale = 0.8;

    [path moveToPoint:CGPointMake(x + w * 0.1, cloudY)];
    [path addLineToPoint:CGPointMake(x + w * 0.75, cloudY)];
    [path addArcWithCenter:CGPointMake(x + w * 0.65, cloudY - h * 0.1 * cloudScale) radius:h * 0.14 * cloudScale startAngle:M_PI_2 endAngle:-M_PI_2 clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.45, cloudY - h * 0.22 * cloudScale) radius:h * 0.18 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.28, cloudY - h * 0.15 * cloudScale) radius:h * 0.15 * cloudScale startAngle:0 endAngle:-M_PI clockwise:NO];
    [path addArcWithCenter:CGPointMake(x + w * 0.15, cloudY - h * 0.06 * cloudScale) radius:h * 0.1 * cloudScale startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:NO];

    return path;
}

#pragma mark - Class Methods

+ (UIImage *)imageWithIconType:(HBIconType)iconType size:(CGSize)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);

    HBIconView *iconView = [[HBIconView alloc] initWithIconType:iconType color:color];
    iconView.frame = CGRectMake(0, 0, size.width, size.height);
    iconView.iconInset = size.width * 0.15;
    [iconView drawRect:iconView.bounds];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end
