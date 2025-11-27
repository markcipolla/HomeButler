#import <UIKit/UIKit.h>

@class HBRoom;
@class HBRoomCell;
@class HAEntity;

@protocol HBRoomCellDelegate <NSObject>

- (void)roomCell:(HBRoomCell *)cell didToggleAllForRoom:(HBRoom *)room toState:(BOOL)on;

@end

@interface HBRoomCell : UICollectionViewCell

@property (nonatomic, weak) id<HBRoomCellDelegate> delegate;
@property (nonatomic, strong) HBRoom *room;

- (void)configureWithRoom:(HBRoom *)room lights:(NSArray<HAEntity *> *)lights;

@end
