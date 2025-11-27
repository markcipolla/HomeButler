#import <UIKit/UIKit.h>

@class HBRoom;
@class HAEntity;

@interface HBRoomDetailViewController : UIViewController

@property (nonatomic, strong) HBRoom *room;
@property (nonatomic, strong) NSArray<HAEntity *> *allEntities;

@end
