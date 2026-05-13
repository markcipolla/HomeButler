#import <UIKit/UIKit.h>
#import "HBRefreshable.h"

@interface UIViewController (HBRefresh)

- (UIRefreshControl *)hb_installPullToRefreshOnScrollView:(UIScrollView *)scrollView;
- (void)hb_installWakeRefreshObserver;
- (void)hb_removeWakeRefreshObserver;
- (void)hb_startRefreshTimer;
- (void)hb_stopRefreshTimer;
- (void)hb_endRefreshing;

@end
