#import "HBPlexNowPlayingPill.h"
#import "HBPlexSession.h"
#import "HBPlexItem.h"
#import "HBPlexClient.h"
#import "HBThemeManager.h"

@interface HBPlexNowPlayingPill ()
@property (nonatomic, strong) UIImageView *thumbView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *progressBar;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) NSURLSessionDataTask *imageTask;
@end

@implementation HBPlexNowPlayingPill

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        HBThemeManager *theme = [HBThemeManager sharedManager];
        self.backgroundColor = [theme cardBackgroundColor];
        self.layer.cornerRadius = 14.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.3;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.shadowRadius = 6;
        [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];

        _thumbView = [[UIImageView alloc] init];
        _thumbView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbView.clipsToBounds = YES;
        _thumbView.layer.cornerRadius = 6.0;
        _thumbView.backgroundColor = [theme backgroundColor];
        _thumbView.userInteractionEnabled = NO;
        [self addSubview:_thumbView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.textColor = [theme textColor];
        _titleLabel.userInteractionEnabled = NO;
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [UIFont systemFontOfSize:12];
        _subtitleLabel.textColor = [theme secondaryTextColor];
        _subtitleLabel.userInteractionEnabled = NO;
        [self addSubview:_subtitleLabel];

        _progressBar = [[UIView alloc] init];
        _progressBar.translatesAutoresizingMaskIntoConstraints = NO;
        _progressBar.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
        _progressBar.userInteractionEnabled = NO;
        [self addSubview:_progressBar];

        _progressFill = [[UIView alloc] init];
        _progressFill.backgroundColor = [theme accentColor] ?: [UIColor yellowColor];
        [_progressBar addSubview:_progressFill];

        [NSLayoutConstraint activateConstraints:@[
            [_thumbView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [_thumbView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_thumbView.widthAnchor constraintEqualToConstant:46],
            [_thumbView.heightAnchor constraintEqualToConstant:46],

            [_titleLabel.leadingAnchor  constraintEqualToAnchor:_thumbView.trailingAnchor constant:10],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-10],
            [_titleLabel.topAnchor      constraintEqualToAnchor:self.topAnchor constant:10],

            [_subtitleLabel.leadingAnchor  constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-10],
            [_subtitleLabel.topAnchor      constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],

            [_progressBar.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
            [_progressBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_progressBar.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
            [_progressBar.heightAnchor   constraintEqualToConstant:3],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat fraction = 0;
    if (self.session.durationMs > 0) {
        fraction = (CGFloat)self.session.viewOffsetMs / (CGFloat)self.session.durationMs;
        if (fraction < 0) fraction = 0;
        if (fraction > 1) fraction = 1;
    }
    self.progressFill.frame = CGRectMake(0, 0, self.progressBar.bounds.size.width * fraction, self.progressBar.bounds.size.height);
}

- (void)tapped {
    if ([self.delegate respondsToSelector:@selector(plexNowPlayingPillDidTap:)]) {
        [self.delegate plexNowPlayingPillDidTap:self];
    }
}

- (void)configureWithSession:(HBPlexSession *)session {
    self.session = session;
    self.titleLabel.text    = session.item.displayTitle;
    self.subtitleLabel.text = session.item.displaySubtitle;
    [self setNeedsLayout];

    NSString *thumb = session.item.preferredThumbKey;
    NSString *capturedKey = session.item.ratingKey;
    [self.imageTask cancel];
    self.thumbView.image = nil;
    if (thumb.length == 0) return;
    __weak typeof(self) weakSelf = self;
    self.imageTask = [[HBPlexClient sharedClient] loadImageForThumbKey:thumb size:CGSizeMake(46, 46) completion:^(UIImage *image, NSError *error) {
        __strong typeof(weakSelf) strong = weakSelf;
        if (!strong) return;
        if (![strong.session.item.ratingKey isEqualToString:capturedKey]) return;
        if (image) strong.thumbView.image = image;
    }];
}

@end
