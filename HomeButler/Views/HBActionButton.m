#import "HBActionButton.h"
#import "HBThemeManager.h"

static const CGFloat kTextButtonWidth = 100.0;
static const CGFloat kTextButtonHeight = 50.0;
static const CGFloat kIconButtonSize = 50.0;
static const CGFloat kIconImageSize = 28.0;
static const CGFloat kCornerRadius = 12.0;

@interface HBActionButton ()

@property (nonatomic, assign) HBIconType iconType;

@end

@implementation HBActionButton

+ (instancetype)textButtonWithTitle:(NSString *)title {
    HBActionButton *button = [HBActionButton buttonWithType:UIButtonTypeCustom];
    button.buttonStyle = HBActionButtonStyleText;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    HBThemeManager *theme = [HBThemeManager sharedManager];

    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[theme textColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    button.backgroundColor = [theme secondaryBackgroundColor];
    button.layer.cornerRadius = kCornerRadius;

    // Set intrinsic content size via constraints
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:kTextButtonWidth],
        [button.heightAnchor constraintEqualToConstant:kTextButtonHeight]
    ]];

    return button;
}

+ (instancetype)iconButtonWithType:(HBIconType)iconType {
    HBActionButton *button = [HBActionButton buttonWithType:UIButtonTypeCustom];
    button.buttonStyle = HBActionButtonStyleIcon;
    button.iconType = iconType;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    HBThemeManager *theme = [HBThemeManager sharedManager];

    UIImage *icon = [HBIconView imageWithIconType:iconType size:CGSizeMake(kIconImageSize, kIconImageSize) color:[theme textColor]];
    [button setImage:icon forState:UIControlStateNormal];
    button.backgroundColor = [theme secondaryBackgroundColor];
    button.layer.cornerRadius = kCornerRadius;

    // Set intrinsic content size via constraints
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:kIconButtonSize],
        [button.heightAnchor constraintEqualToConstant:kIconButtonSize]
    ]];

    return button;
}

- (void)setIconType:(HBIconType)iconType {
    _iconType = iconType;

    if (self.buttonStyle == HBActionButtonStyleIcon) {
        HBThemeManager *theme = [HBThemeManager sharedManager];
        UIColor *iconColor = self.isActive ? [UIColor blackColor] : [theme textColor];
        UIImage *icon = [HBIconView imageWithIconType:iconType size:CGSizeMake(kIconImageSize, kIconImageSize) color:iconColor];
        [self setImage:icon forState:UIControlStateNormal];
    }
}

- (void)setActive:(BOOL)active {
    _isActive = active;

    HBThemeManager *theme = [HBThemeManager sharedManager];

    if (active) {
        self.backgroundColor = [theme onColor];
        self.layer.borderWidth = 2;
        self.layer.borderColor = [UIColor whiteColor].CGColor;

        if (self.buttonStyle == HBActionButtonStyleText) {
            [self setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        } else {
            UIImage *icon = [HBIconView imageWithIconType:self.iconType size:CGSizeMake(kIconImageSize, kIconImageSize) color:[UIColor blackColor]];
            [self setImage:icon forState:UIControlStateNormal];
        }
    } else {
        self.backgroundColor = [theme secondaryBackgroundColor];
        self.layer.borderWidth = 0;

        if (self.buttonStyle == HBActionButtonStyleText) {
            [self setTitleColor:[theme textColor] forState:UIControlStateNormal];
        } else {
            UIImage *icon = [HBIconView imageWithIconType:self.iconType size:CGSizeMake(kIconImageSize, kIconImageSize) color:[theme textColor]];
            [self setImage:icon forState:UIControlStateNormal];
        }
    }
}

@end
