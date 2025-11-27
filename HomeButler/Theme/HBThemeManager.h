#import <UIKit/UIKit.h>

@interface HBThemeManager : NSObject

+ (instancetype)sharedManager;

// Colors
- (UIColor *)backgroundColor;
- (UIColor *)secondaryBackgroundColor;
- (UIColor *)cardBackgroundColor;
- (UIColor *)textColor;
- (UIColor *)secondaryTextColor;
- (UIColor *)accentColor;
- (UIColor *)onColor;
- (UIColor *)offColor;
- (UIColor *)separatorColor;

// Apply theme to navigation bar
- (void)applyThemeToNavigationBar:(UINavigationBar *)navigationBar;

@end
