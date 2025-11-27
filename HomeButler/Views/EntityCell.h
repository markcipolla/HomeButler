#import <UIKit/UIKit.h>

@class HAEntity;

@interface EntityCell : UITableViewCell

@property (nonatomic, strong) HAEntity *entity;

- (void)configureWithEntity:(HAEntity *)entity;

@end
