#import <UIKit/UIKit.h>
#import "HBRefreshable.h"

@class HBPlexItem;

typedef NS_ENUM(NSInteger, HBPlexShowMode) {
    HBPlexShowModeShow   = 0, // show -> seasons
    HBPlexShowModeSeason = 1  // season -> episodes
};

@interface HBPlexShowViewController : UIViewController <HBRefreshable>

- (instancetype)initWithItem:(HBPlexItem *)item mode:(HBPlexShowMode)mode;

@end
