#import "HBThemeManager.h"

@implementation HBThemeManager

+ (instancetype)sharedManager {
    static HBThemeManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (UIColor *)backgroundColor {
    // Dark background
    return [UIColor colorWithRed:18/255.0 green:18/255.0 blue:24/255.0 alpha:1.0];
}

- (UIColor *)secondaryBackgroundColor {
    // Slightly lighter dark
    return [UIColor colorWithRed:28/255.0 green:28/255.0 blue:36/255.0 alpha:1.0];
}

- (UIColor *)cardBackgroundColor {
    // Card/cell background
    return [UIColor colorWithRed:38/255.0 green:38/255.0 blue:48/255.0 alpha:1.0];
}

- (UIColor *)textColor {
    // Primary text - white
    return [UIColor colorWithRed:245/255.0 green:245/255.0 blue:247/255.0 alpha:1.0];
}

- (UIColor *)secondaryTextColor {
    // Secondary text - gray
    return [UIColor colorWithRed:142/255.0 green:142/255.0 blue:147/255.0 alpha:1.0];
}

- (UIColor *)accentColor {
    // Blue accent
    return [UIColor colorWithRed:64/255.0 green:156/255.0 blue:255/255.0 alpha:1.0];
}

- (UIColor *)onColor {
    // Bright yellow/amber for "on" state
    return [UIColor colorWithRed:255/255.0 green:204/255.0 blue:0/255.0 alpha:1.0];
}

- (UIColor *)offColor {
    // Muted gray for "off" state
    return [UIColor colorWithRed:72/255.0 green:72/255.0 blue:74/255.0 alpha:1.0];
}

- (UIColor *)separatorColor {
    return [UIColor colorWithRed:58/255.0 green:58/255.0 blue:60/255.0 alpha:1.0];
}

- (void)applyThemeToNavigationBar:(UINavigationBar *)navigationBar {
    navigationBar.barTintColor = [self secondaryBackgroundColor];
    navigationBar.tintColor = [self accentColor];
    navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [self textColor]};
    navigationBar.translucent = NO;
}

@end
