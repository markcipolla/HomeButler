#import <UIKit/UIKit.h>

@class HBPlexItem;

@interface HBPlexMediaCell : UICollectionViewCell

@property (nonatomic, strong, readonly) UIImageView *posterView;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readonly) UIView *progressBar;
@property (nonatomic, strong) HBPlexItem *item;

- (void)configureWithItem:(HBPlexItem *)item;

@end
