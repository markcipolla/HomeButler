#import "HBRoomCell.h"
#import "HBRoom.h"
#import "HBThemeManager.h"
#import "HAEntity.h"
#import "HBIconView.h"

@interface HBRoomCell ()

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *chipsContainerView;
@property (nonatomic, strong) HBIconView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) NSArray<HAEntity *> *lights;

@end

@implementation HBRoomCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    self.contentView.backgroundColor = [UIColor clearColor];
    self.contentView.layer.cornerRadius = 16;
    self.contentView.layer.masksToBounds = YES;

    // Header view (lighter background)
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [theme cardBackgroundColor];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.headerView];

    // Chips container (darker background)
    self.chipsContainerView = [[UIView alloc] init];
    self.chipsContainerView.backgroundColor = [theme secondaryBackgroundColor];
    self.chipsContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.chipsContainerView];

    // Icon
    self.iconView = [[HBIconView alloc] initWithIconType:HBIconTypeLivingRoom color:[theme textColor]];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:self.iconView];

    // Name
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont boldSystemFontOfSize:16];
    self.nameLabel.textColor = [theme textColor];
    self.nameLabel.textAlignment = NSTextAlignmentLeft;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:self.nameLabel];

    // Status (e.g., "2 of 4 lights on")
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textColor = [theme secondaryTextColor];
    self.statusLabel.textAlignment = NSTextAlignmentLeft;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:self.statusLabel];

    // Toggle button
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleButton.layer.cornerRadius = 25;
    self.toggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toggleButton addTarget:self action:@selector(toggleTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.toggleButton];

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        // Header view - top portion
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.headerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.headerView.heightAnchor constraintEqualToConstant:70],

        // Chips container - bottom portion
        [self.chipsContainerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.chipsContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.chipsContainerView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        [self.chipsContainerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        // Icon on left
        [self.iconView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:16],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:36],
        [self.iconView.heightAnchor constraintEqualToConstant:36],

        // Toggle button on right
        [self.toggleButton.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-12],
        [self.toggleButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.toggleButton.widthAnchor constraintEqualToConstant:50],
        [self.toggleButton.heightAnchor constraintEqualToConstant:50],

        // Name and status in middle
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:12],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.toggleButton.leadingAnchor constant:-8],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:18],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
    ]];
}

- (void)configureWithRoom:(HBRoom *)room lights:(NSArray<HAEntity *> *)lights {
    self.room = room;
    self.lights = lights;

    self.iconView.iconType = (HBIconType)room.iconType;
    self.nameLabel.text = room.name;

    NSInteger lightCount = lights.count;
    NSInteger onCount = 0;
    for (HAEntity *entity in lights) {
        if (entity.isOn) onCount++;
    }

    if (lightCount == 0) {
        self.statusLabel.text = @"No lights";
    } else if (onCount == 0) {
        self.statusLabel.text = @"All off";
    } else if (onCount == lightCount) {
        self.statusLabel.text = @"All on";
    } else {
        self.statusLabel.text = [NSString stringWithFormat:@"%ld of %ld on", (long)onCount, (long)lightCount];
    }

    HBThemeManager *theme = [HBThemeManager sharedManager];

    // Update toggle button appearance
    if (onCount > 0) {
        self.headerView.backgroundColor = [[theme onColor] colorWithAlphaComponent:0.15];
        self.iconView.iconColor = [theme onColor];
        self.toggleButton.backgroundColor = [theme onColor];
        [self.toggleButton setTitle:@"ON" forState:UIControlStateNormal];
        [self.toggleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    } else {
        self.headerView.backgroundColor = [theme cardBackgroundColor];
        self.iconView.iconColor = [theme secondaryTextColor];
        self.toggleButton.backgroundColor = [theme secondaryBackgroundColor];
        [self.toggleButton setTitle:@"OFF" forState:UIControlStateNormal];
        [self.toggleButton setTitleColor:[theme secondaryTextColor] forState:UIControlStateNormal];
    }

    self.toggleButton.hidden = (lightCount == 0);

    // Update chips
    [self updateChips];
}

- (void)updateChips {
    // Remove existing chips
    for (UIView *subview in self.chipsContainerView.subviews) {
        [subview removeFromSuperview];
    }

    if (self.lights.count == 0) {
        self.chipsContainerView.hidden = YES;
        return;
    }

    self.chipsContainerView.hidden = NO;
    HBThemeManager *theme = [HBThemeManager sharedManager];

    CGFloat chipHeight = 26;
    CGFloat chipPadding = 8;
    CGFloat xOffset = 12;
    CGFloat yOffset = 8;
    CGFloat maxWidth = self.contentView.bounds.size.width - 24;

    for (HAEntity *light in self.lights) {
        // Create chip
        UIView *chip = [[UIView alloc] init];
        chip.layer.cornerRadius = chipHeight / 2;

        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:11];
        label.text = light.friendlyName;
        label.translatesAutoresizingMaskIntoConstraints = NO;

        if (light.isOn) {
            chip.backgroundColor = [theme onColor];
            label.textColor = [UIColor blackColor];
        } else {
            chip.backgroundColor = [[theme secondaryTextColor] colorWithAlphaComponent:0.3];
            label.textColor = [theme secondaryTextColor];
        }

        [chip addSubview:label];

        // Size the chip based on text
        [label sizeToFit];
        CGFloat chipWidth = label.bounds.size.width + 20; // padding

        // Check if we need to wrap to next line
        if (xOffset + chipWidth > maxWidth && xOffset > 12) {
            xOffset = 12;
            yOffset += chipHeight + 6;
        }

        chip.frame = CGRectMake(xOffset, yOffset, chipWidth, chipHeight);

        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
            [label.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        ]];

        [self.chipsContainerView addSubview:chip];
        xOffset += chipWidth + chipPadding;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    for (UIView *subview in self.chipsContainerView.subviews) {
        [subview removeFromSuperview];
    }
}

- (void)toggleTapped {
    NSInteger onCount = 0;
    for (HAEntity *entity in self.lights) {
        if (entity.isOn) onCount++;
    }

    BOOL newState = (onCount == 0);

    if ([self.delegate respondsToSelector:@selector(roomCell:didToggleAllForRoom:toState:)]) {
        [self.delegate roomCell:self didToggleAllForRoom:self.room toState:newState];
    }
}

@end
