#import <UIKit/UIKit.h>
#import "HBRefreshable.h"

@interface HBPlexSearchViewController : UIViewController <HBRefreshable>

- (instancetype)initWithQuery:(NSString *)query;

@end
