#import <UIKit/UIKit.h>

// Icon names that correspond to SVG files
typedef NS_ENUM(NSInteger, HBIconType) {
    HBIconTypeHouse,
    HBIconTypeLivingRoom,
    HBIconTypeKitchen,
    HBIconTypeBathTub,
    HBIconTypeBed,
    HBIconTypeGarage,
    HBIconTypeWork,
    HBIconTypeBabyCrib,
    HBIconTypeGear,
    HBIconTypePlus,
    HBIconTypePencil,
    // Weather icons
    HBIconTypeSun,
    HBIconTypeCloud,
    HBIconTypeRain,
    HBIconTypeSnow,
    HBIconTypeStorm,
    HBIconTypePartlyCloudy
};

@interface HBIconView : UIView

@property (nonatomic, assign) HBIconType iconType;
@property (nonatomic, strong) UIColor *iconColor;
@property (nonatomic, assign) CGFloat iconInset; // Padding inside the view

- (instancetype)initWithIconType:(HBIconType)iconType;
- (instancetype)initWithIconType:(HBIconType)iconType color:(UIColor *)color;

// Convenience method to get an image from the icon (for buttons)
+ (UIImage *)imageWithIconType:(HBIconType)iconType size:(CGSize)size color:(UIColor *)color;

@end
