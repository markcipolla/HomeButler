#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBBatteryReporter : NSObject

+ (instancetype)sharedReporter;

// Start/stop periodic reporting (every 60 seconds)
- (void)startReporting;
- (void)stopReporting;

// Manual report trigger
- (void)reportNow;

@end

NS_ASSUME_NONNULL_END
