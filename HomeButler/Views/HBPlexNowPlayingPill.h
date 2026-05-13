#import <UIKit/UIKit.h>

@class HBPlexSession;
@class HBPlexNowPlayingPill;

@protocol HBPlexNowPlayingPillDelegate <NSObject>
- (void)plexNowPlayingPillDidTap:(HBPlexNowPlayingPill *)pill;
@end

@interface HBPlexNowPlayingPill : UIControl

@property (nonatomic, weak)   id<HBPlexNowPlayingPillDelegate> delegate;
@property (nonatomic, strong) HBPlexSession *session;

- (void)configureWithSession:(HBPlexSession *)session;

@end
