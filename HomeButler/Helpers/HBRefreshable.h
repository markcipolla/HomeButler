#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, HBRefreshSource) {
    HBRefreshSourcePullToRefresh = 1 << 0,
    HBRefreshSourceWakeFromSleep = 1 << 1,
    HBRefreshSourceTimer         = 1 << 2,
    HBRefreshSourceManual        = 1 << 3
};

@protocol HBRefreshable <NSObject>
@required
- (void)refreshFromSource:(HBRefreshSource)source;
@optional
- (NSTimeInterval)refreshPollingInterval; // default 5.0
- (BOOL)refreshShouldPollWhenVisible;     // default YES
@end
