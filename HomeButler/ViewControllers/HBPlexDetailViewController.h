#import <UIKit/UIKit.h>
#import "HBRefreshable.h"

@class HBPlexItem;

@interface HBPlexDetailViewController : UIViewController <HBRefreshable>

- (instancetype)initWithItem:(HBPlexItem *)item;

@end
