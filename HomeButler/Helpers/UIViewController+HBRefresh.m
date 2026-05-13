#import "UIViewController+HBRefresh.h"
#import <objc/runtime.h>

static const void *kHBRefreshControlKey   = &kHBRefreshControlKey;
static const void *kHBRefreshTimerKey     = &kHBRefreshTimerKey;
static const void *kHBWakeObserverFlagKey = &kHBWakeObserverFlagKey;
static const void *kHBBgObserverFlagKey   = &kHBBgObserverFlagKey;

@implementation UIViewController (HBRefresh)

#pragma mark - Pull to refresh

- (UIRefreshControl *)hb_installPullToRefreshOnScrollView:(UIScrollView *)scrollView {
    if (!scrollView) return nil;
    UIRefreshControl *rc = [[UIRefreshControl alloc] init];
    rc.tintColor = [UIColor whiteColor];
    [rc addTarget:self action:@selector(hb_pullRefreshTriggered:) forControlEvents:UIControlEventValueChanged];
    if ([scrollView isKindOfClass:[UITableView class]] || [scrollView isKindOfClass:[UICollectionView class]]) {
        // iOS 10+ has refreshControl property; for iOS 9 just addSubview.
        [scrollView addSubview:rc];
    } else {
        scrollView.alwaysBounceVertical = YES;
        [scrollView addSubview:rc];
    }
    objc_setAssociatedObject(self, kHBRefreshControlKey, rc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return rc;
}

- (void)hb_pullRefreshTriggered:(UIRefreshControl *)sender {
    if ([self conformsToProtocol:@protocol(HBRefreshable)]) {
        [(id<HBRefreshable>)self refreshFromSource:HBRefreshSourcePullToRefresh];
    } else {
        [sender endRefreshing];
    }
}

- (void)hb_endRefreshing {
    UIRefreshControl *rc = objc_getAssociatedObject(self, kHBRefreshControlKey);
    if (rc.isRefreshing) {
        [rc endRefreshing];
    }
}

#pragma mark - Wake observer

- (void)hb_installWakeRefreshObserver {
    NSNumber *installed = objc_getAssociatedObject(self, kHBWakeObserverFlagKey);
    if (installed.boolValue) return;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hb_didBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hb_didEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    objc_setAssociatedObject(self, kHBWakeObserverFlagKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)hb_removeWakeRefreshObserver {
    NSNumber *installed = objc_getAssociatedObject(self, kHBWakeObserverFlagKey);
    if (!installed.boolValue) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    objc_setAssociatedObject(self, kHBWakeObserverFlagKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)hb_didBecomeActive:(NSNotification *)note {
    if (![self isViewLoaded] || self.view.window == nil) return;
    if ([self conformsToProtocol:@protocol(HBRefreshable)]) {
        [(id<HBRefreshable>)self refreshFromSource:HBRefreshSourceWakeFromSleep];
    }
    // Re-arm timer if it was running pre-background
    NSNumber *wasBg = objc_getAssociatedObject(self, kHBBgObserverFlagKey);
    if (wasBg.boolValue) {
        objc_setAssociatedObject(self, kHBBgObserverFlagKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self hb_startRefreshTimer];
    }
}

- (void)hb_didEnterBackground:(NSNotification *)note {
    NSTimer *t = objc_getAssociatedObject(self, kHBRefreshTimerKey);
    if (t) {
        [t invalidate];
        objc_setAssociatedObject(self, kHBRefreshTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, kHBBgObserverFlagKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - Timer

- (void)hb_startRefreshTimer {
    NSTimer *existing = objc_getAssociatedObject(self, kHBRefreshTimerKey);
    if (existing) return;

    NSTimeInterval interval = 5.0;
    if ([self conformsToProtocol:@protocol(HBRefreshable)]
        && [self respondsToSelector:@selector(refreshPollingInterval)]) {
        interval = [(id<HBRefreshable>)self refreshPollingInterval];
    }
    if (interval <= 0) return;

    BOOL shouldPoll = YES;
    if ([self conformsToProtocol:@protocol(HBRefreshable)]
        && [self respondsToSelector:@selector(refreshShouldPollWhenVisible)]) {
        shouldPoll = [(id<HBRefreshable>)self refreshShouldPollWhenVisible];
    }
    if (!shouldPoll) return;

    NSTimer *timer = [NSTimer timerWithTimeInterval:interval
                                             target:self
                                           selector:@selector(hb_timerFired:)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(self, kHBRefreshTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)hb_stopRefreshTimer {
    NSTimer *t = objc_getAssociatedObject(self, kHBRefreshTimerKey);
    if (t) {
        [t invalidate];
        objc_setAssociatedObject(self, kHBRefreshTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)hb_timerFired:(NSTimer *)timer {
    if ([self conformsToProtocol:@protocol(HBRefreshable)]) {
        [(id<HBRefreshable>)self refreshFromSource:HBRefreshSourceTimer];
    }
}

@end
