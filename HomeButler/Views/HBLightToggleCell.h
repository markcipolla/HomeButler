#import <UIKit/UIKit.h>

@class HAEntity;

@class HBLightToggleCell;

@protocol HBLightToggleCellDelegate <NSObject>
// Entity may be nil if it was deallocated - use cell.entityId for API calls
- (void)lightToggleCell:(HBLightToggleCell *)cell didToggleEntity:(HAEntity *)entity toState:(BOOL)on;
- (void)lightToggleCell:(HBLightToggleCell *)cell didSetBrightness:(NSInteger)brightness forEntity:(HAEntity *)entity;
@optional
// For scripts - triggers script execution (entity may be nil, use cell.entityId)
- (void)lightToggleCell:(HBLightToggleCell *)cell didTriggerScript:(HAEntity *)entity;
// Called when user starts/stops interacting with cell (brightness slider)
- (void)lightToggleCell:(HBLightToggleCell *)cell didChangeInteractionState:(BOOL)isInteracting;
@end

@interface HBLightToggleCell : UICollectionViewCell

@property (nonatomic, weak) id<HBLightToggleCellDelegate> delegate;
// Entity is weak - may become nil if the entity is replaced
@property (nonatomic, weak, readonly) HAEntity *entity;
// EntityId is always available - use this for API calls
@property (nonatomic, copy, readonly) NSString *entityId;

- (void)configureWithEntity:(HAEntity *)entity;

@end
