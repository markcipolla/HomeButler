#import <UIKit/UIKit.h>

@class HBRoom;
@class HAEntity;

@interface HBAddRoomViewController : UIViewController

@property (nonatomic, strong) HBRoom *room; // nil for new room, set for editing
@property (nonatomic, strong) NSArray<HAEntity *> *allEntities;

@end
