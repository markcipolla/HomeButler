#import "HBPlexMediaCell.h"
#import "HBPlexItem.h"
#import "HBPlexClient.h"
#import "HBThemeManager.h"

@interface HBPlexMediaCell ()
@property (nonatomic, strong) UIImageView *posterView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *progressBar;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) NSURLSessionDataTask *imageTask;
@end

@implementation HBPlexMediaCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        HBThemeManager *theme = [HBThemeManager sharedManager];

        self.contentView.backgroundColor = [UIColor clearColor];

        _posterView = [[UIImageView alloc] init];
        _posterView.translatesAutoresizingMaskIntoConstraints = NO;
        _posterView.contentMode = UIViewContentModeScaleAspectFill;
        _posterView.clipsToBounds = YES;
        _posterView.backgroundColor = [theme cardBackgroundColor];
        _posterView.layer.cornerRadius = 6.0;
        [self.contentView addSubview:_posterView];

        _progressBar = [[UIView alloc] init];
        _progressBar.translatesAutoresizingMaskIntoConstraints = NO;
        _progressBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
        _progressBar.hidden = YES;
        _progressBar.layer.cornerRadius = 1.0;
        _progressBar.clipsToBounds = YES;
        [self.contentView addSubview:_progressBar];

        _progressFill = [[UIView alloc] init];
        _progressFill.backgroundColor = [theme accentColor] ?: [UIColor yellowColor];
        [_progressBar addSubview:_progressFill];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _titleLabel.textColor = [theme textColor];
        _titleLabel.numberOfLines = 1;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [UIFont systemFontOfSize:11];
        _subtitleLabel.textColor = [theme secondaryTextColor];
        _subtitleLabel.numberOfLines = 1;
        [self.contentView addSubview:_subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_posterView.topAnchor       constraintEqualToAnchor:self.contentView.topAnchor],
            [_posterView.leadingAnchor   constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_posterView.trailingAnchor  constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_posterView.heightAnchor    constraintEqualToAnchor:_posterView.widthAnchor multiplier:1.5],

            [_progressBar.leadingAnchor  constraintEqualToAnchor:_posterView.leadingAnchor constant:4],
            [_progressBar.trailingAnchor constraintEqualToAnchor:_posterView.trailingAnchor constant:-4],
            [_progressBar.bottomAnchor   constraintEqualToAnchor:_posterView.bottomAnchor constant:-4],
            [_progressBar.heightAnchor   constraintEqualToConstant:2],

            [_titleLabel.topAnchor       constraintEqualToAnchor:_posterView.bottomAnchor constant:6],
            [_titleLabel.leadingAnchor   constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_titleLabel.trailingAnchor  constraintEqualToAnchor:self.contentView.trailingAnchor],

            [_subtitleLabel.topAnchor      constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat fraction = self.item.progressFraction;
    self.progressFill.frame = CGRectMake(0, 0, self.progressBar.bounds.size.width * fraction, self.progressBar.bounds.size.height);
}

- (void)configureWithItem:(HBPlexItem *)item {
    self.item = item;
    self.titleLabel.text    = item.displayTitle;
    self.subtitleLabel.text = item.displaySubtitle;

    CGFloat fraction = item.progressFraction;
    self.progressBar.hidden = (fraction <= 0.001);
    [self setNeedsLayout];

    self.posterView.image = nil;
    NSString *capturedKey = item.ratingKey;
    NSString *thumb = item.preferredThumbKey;
    if (thumb.length == 0) return;
    CGSize size = self.posterView.bounds.size;
    if (size.width <= 0) size = CGSizeMake(120, 180);
    __weak typeof(self) weakSelf = self;
    self.imageTask = [[HBPlexClient sharedClient] loadImageForThumbKey:thumb size:size completion:^(UIImage *image, NSError *error) {
        __strong typeof(weakSelf) strong = weakSelf;
        if (!strong) return;
        if (![strong.item.ratingKey isEqualToString:capturedKey]) return;
        if (image) strong.posterView.image = image;
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.imageTask cancel];
    self.imageTask = nil;
    self.posterView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.progressBar.hidden = YES;
    self.item = nil;
}

@end
