#import <UIKit/UIKit.h>
#import "HBIconView.h"

typedef NS_ENUM(NSInteger, HBActionButtonStyle) {
    HBActionButtonStyleText,    // Text button (All On, All Off)
    HBActionButtonStyleIcon     // Icon-only button (Edit pencil)
};

@interface HBActionButton : UIButton

@property (nonatomic, assign) HBActionButtonStyle buttonStyle;
@property (nonatomic, assign) BOOL isActive; // Whether button shows active/highlighted state

// Factory methods
+ (instancetype)textButtonWithTitle:(NSString *)title;
+ (instancetype)iconButtonWithType:(HBIconType)iconType;

// For icon buttons - update the icon
- (void)setIconType:(HBIconType)iconType;

// Update active state (for All On/All Off toggle feedback)
- (void)setActive:(BOOL)active;

@end
