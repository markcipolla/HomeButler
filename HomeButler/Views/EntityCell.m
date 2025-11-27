#import "EntityCell.h"
#import "HAEntity.h"

@interface EntityCell ()

@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UIView *statusIndicator;

@end

@implementation EntityCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 30, 30)];
        self.iconLabel.font = [UIFont systemFontOfSize:24];
        self.iconLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:self.iconLabel];

        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(55, 8, 200, 20)];
        self.nameLabel.font = [UIFont boldSystemFontOfSize:16];
        [self.contentView addSubview:self.nameLabel];

        self.stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(55, 28, 200, 16)];
        self.stateLabel.font = [UIFont systemFontOfSize:13];
        self.stateLabel.textColor = [UIColor grayColor];
        [self.contentView addSubview:self.stateLabel];

        self.statusIndicator = [[UIView alloc] initWithFrame:CGRectMake(self.contentView.bounds.size.width - 30, 15, 20, 20)];
        self.statusIndicator.layer.cornerRadius = 10;
        self.statusIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [self.contentView addSubview:self.statusIndicator];

        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)configureWithEntity:(HAEntity *)entity {
    self.entity = entity;
    self.iconLabel.text = entity.icon;
    self.nameLabel.text = entity.friendlyName;
    self.stateLabel.text = entity.state;
    self.statusIndicator.backgroundColor = entity.stateColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.statusIndicator.frame = CGRectMake(self.contentView.bounds.size.width - 50, 15, 20, 20);
}

@end
