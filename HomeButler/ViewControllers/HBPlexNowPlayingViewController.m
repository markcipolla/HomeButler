#import "HBPlexNowPlayingViewController.h"
#import "HBPlexClient.h"
#import "HBPlexSession.h"
#import "HBPlexItem.h"
#import "HBPlexStream.h"
#import "UIViewController+HBRefresh.h"
#import "HBThemeManager.h"

@interface HBPlexNowPlayingViewController ()
@property (nonatomic, strong) HBPlexSession *session;
@property (nonatomic, strong) UIImageView *backdropView;
@property (nonatomic, strong) UIView *backdropDim;
@property (nonatomic, strong) UIImageView *artView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISlider *seekSlider;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *remainingLabel;
@property (nonatomic, strong) UIButton *skipPrevButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UIButton *skipNextButton;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) UIButton *audioButton;
@property (nonatomic, strong) UIButton *subtitlesButton;
@property (nonatomic, assign) BOOL isSeekScrubbing;
@property (nonatomic, assign) BOOL isVolumeScrubbing;
@property (nonatomic, assign) NSInteger missCount;
@property (nonatomic, copy) NSString *currentArtKey;
@end

@implementation HBPlexNowPlayingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    HBThemeManager *theme = [HBThemeManager sharedManager];
    self.view.backgroundColor = [theme backgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(closeTapped)];

    self.backdropView = [[UIImageView alloc] init];
    self.backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backdropView.contentMode = UIViewContentModeScaleAspectFill;
    self.backdropView.clipsToBounds = YES;
    [self.view addSubview:self.backdropView];

    self.backdropDim = [[UIView alloc] init];
    self.backdropDim.translatesAutoresizingMaskIntoConstraints = NO;
    self.backdropDim.backgroundColor = [[theme backgroundColor] colorWithAlphaComponent:0.85];
    [self.view addSubview:self.backdropDim];

    self.artView = [[UIImageView alloc] init];
    self.artView.translatesAutoresizingMaskIntoConstraints = NO;
    self.artView.contentMode = UIViewContentModeScaleAspectFit;
    self.artView.backgroundColor = [theme cardBackgroundColor];
    [self.view addSubview:self.artView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.titleLabel.textColor = [theme textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    [self.view addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [UIFont systemFontOfSize:14];
    self.subtitleLabel.textColor = [theme secondaryTextColor];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.subtitleLabel];

    self.seekSlider = [[UISlider alloc] init];
    self.seekSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.seekSlider.minimumTrackTintColor = [theme onColor];
    [self.seekSlider addTarget:self action:@selector(seekTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.seekSlider addTarget:self action:@selector(seekTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider addTarget:self action:@selector(seekTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self.seekSlider addTarget:self action:@selector(seekChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.seekSlider];

    self.elapsedLabel = [[UILabel alloc] init];
    self.elapsedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.elapsedLabel.font = [UIFont systemFontOfSize:12];
    self.elapsedLabel.textColor = [theme secondaryTextColor];
    self.elapsedLabel.text = @"0:00";
    [self.view addSubview:self.elapsedLabel];

    self.remainingLabel = [[UILabel alloc] init];
    self.remainingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.remainingLabel.font = [UIFont systemFontOfSize:12];
    self.remainingLabel.textColor = [theme secondaryTextColor];
    self.remainingLabel.textAlignment = NSTextAlignmentRight;
    self.remainingLabel.text = @"0:00";
    [self.view addSubview:self.remainingLabel];

    self.skipPrevButton  = [self makeTransportButtonTitle:@"<<"];
    self.playPauseButton = [self makeTransportButtonTitle:@"Pause"];
    self.stopButton      = [self makeTransportButtonTitle:@"Stop"];
    self.skipNextButton  = [self makeTransportButtonTitle:@">>"];
    self.playPauseButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.skipPrevButton  addTarget:self action:@selector(prevTapped)      forControlEvents:UIControlEventTouchUpInside];
    [self.playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stopButton      addTarget:self action:@selector(stopTapped)      forControlEvents:UIControlEventTouchUpInside];
    [self.skipNextButton  addTarget:self action:@selector(nextTapped)      forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.skipPrevButton];
    [self.view addSubview:self.playPauseButton];
    [self.view addSubview:self.stopButton];
    [self.view addSubview:self.skipNextButton];

    self.volumeSlider = [[UISlider alloc] init];
    self.volumeSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.volumeSlider.minimumValue = 0.0;
    self.volumeSlider.maximumValue = 1.0;
    self.volumeSlider.minimumTrackTintColor = [theme onColor];
    [self.volumeSlider addTarget:self action:@selector(volumeTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.volumeSlider addTarget:self action:@selector(volumeTouchUp)   forControlEvents:UIControlEventTouchUpInside];
    [self.volumeSlider addTarget:self action:@selector(volumeTouchUp)   forControlEvents:UIControlEventTouchUpOutside];
    [self.view addSubview:self.volumeSlider];

    self.audioButton = [self makePillTitle:@"Audio"];
    [self.audioButton addTarget:self action:@selector(audioTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.audioButton];

    self.subtitlesButton = [self makePillTitle:@"Subtitles"];
    [self.subtitlesButton addTarget:self action:@selector(subtitlesTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.subtitlesButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.backdropView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [self.backdropView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backdropView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [self.backdropDim.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [self.backdropDim.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backdropDim.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backdropDim.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [self.artView.topAnchor      constraintEqualToAnchor:self.view.topAnchor constant:24],
        [self.artView.centerXAnchor  constraintEqualToAnchor:self.view.centerXAnchor],
        [self.artView.widthAnchor    constraintEqualToConstant:200],
        [self.artView.heightAnchor   constraintEqualToConstant:300],

        [self.titleLabel.topAnchor      constraintEqualToAnchor:self.artView.bottomAnchor constant:16],
        [self.titleLabel.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [self.subtitleLabel.topAnchor      constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.subtitleLabel.leadingAnchor  constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.seekSlider.topAnchor      constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:20],
        [self.seekSlider.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.seekSlider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [self.elapsedLabel.topAnchor      constraintEqualToAnchor:self.seekSlider.bottomAnchor constant:4],
        [self.elapsedLabel.leadingAnchor  constraintEqualToAnchor:self.seekSlider.leadingAnchor],

        [self.remainingLabel.topAnchor      constraintEqualToAnchor:self.elapsedLabel.topAnchor],
        [self.remainingLabel.trailingAnchor constraintEqualToAnchor:self.seekSlider.trailingAnchor],

        [self.playPauseButton.topAnchor     constraintEqualToAnchor:self.elapsedLabel.bottomAnchor constant:16],
        [self.playPauseButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.playPauseButton.widthAnchor   constraintEqualToConstant:100],
        [self.playPauseButton.heightAnchor  constraintEqualToConstant:50],

        [self.skipPrevButton.centerYAnchor  constraintEqualToAnchor:self.playPauseButton.centerYAnchor],
        [self.skipPrevButton.trailingAnchor constraintEqualToAnchor:self.playPauseButton.leadingAnchor constant:-16],
        [self.skipPrevButton.widthAnchor    constraintEqualToConstant:60],
        [self.skipPrevButton.heightAnchor   constraintEqualToConstant:44],

        [self.skipNextButton.centerYAnchor constraintEqualToAnchor:self.playPauseButton.centerYAnchor],
        [self.skipNextButton.leadingAnchor constraintEqualToAnchor:self.playPauseButton.trailingAnchor constant:16],
        [self.skipNextButton.widthAnchor   constraintEqualToConstant:60],
        [self.skipNextButton.heightAnchor  constraintEqualToConstant:44],

        [self.stopButton.topAnchor     constraintEqualToAnchor:self.playPauseButton.bottomAnchor constant:12],
        [self.stopButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stopButton.widthAnchor   constraintEqualToConstant:80],
        [self.stopButton.heightAnchor  constraintEqualToConstant:36],

        [self.volumeSlider.topAnchor      constraintEqualToAnchor:self.stopButton.bottomAnchor constant:20],
        [self.volumeSlider.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.volumeSlider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [self.audioButton.topAnchor      constraintEqualToAnchor:self.volumeSlider.bottomAnchor constant:20],
        [self.audioButton.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.audioButton.widthAnchor    constraintEqualToConstant:140],
        [self.audioButton.heightAnchor   constraintEqualToConstant:40],

        [self.subtitlesButton.topAnchor     constraintEqualToAnchor:self.audioButton.topAnchor],
        [self.subtitlesButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.subtitlesButton.widthAnchor   constraintEqualToConstant:140],
        [self.subtitlesButton.heightAnchor  constraintEqualToConstant:40],
    ]];

    [self hb_installWakeRefreshObserver];
}

- (UIButton *)makeTransportButtonTitle:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[[HBThemeManager sharedManager] textColor] forState:UIControlStateNormal];
    b.backgroundColor = [[HBThemeManager sharedManager] cardBackgroundColor];
    b.layer.cornerRadius = 8;
    return b;
}

- (UIButton *)makePillTitle:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.titleLabel.font = [UIFont systemFontOfSize:14];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[[HBThemeManager sharedManager] textColor] forState:UIControlStateNormal];
    b.backgroundColor = [[HBThemeManager sharedManager] cardBackgroundColor];
    b.layer.cornerRadius = 8;
    return b;
}

- (void)dealloc {
    [self hb_removeWakeRefreshObserver];
    [self hb_stopRefreshTimer];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self hb_startRefreshTimer];
    [self refreshFromSource:HBRefreshSourceManual];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self hb_stopRefreshTimer];
}

#pragma mark - HBRefreshable

- (NSTimeInterval)refreshPollingInterval { return 2.0; }

- (void)refreshFromSource:(HBRefreshSource)source {
    [[HBPlexClient sharedClient] fetchActiveSessionsWithCompletion:^(NSArray *sessions, NSError *error) {
        [self hb_endRefreshing];
        HBPlexSession *s = sessions.firstObject;
        if (s == nil) {
            self.missCount++;
            if (self.missCount >= 3) {
                [self autoDismiss];
            }
            return;
        }
        self.missCount = 0;
        self.session = s;
        [self applySession:s];
    }];
}

- (void)applySession:(HBPlexSession *)s {
    self.titleLabel.text    = s.item.displayTitle;
    self.subtitleLabel.text = s.item.displaySubtitle;

    NSInteger duration = s.durationMs > 0 ? s.durationMs : s.item.durationMs;
    if (duration > 0) {
        self.seekSlider.maximumValue = (float)duration;
        if (!self.isSeekScrubbing) {
            self.seekSlider.value = (float)s.viewOffsetMs;
            self.elapsedLabel.text   = [self formatMs:s.viewOffsetMs];
            self.remainingLabel.text = [self formatMs:MAX(0, duration - s.viewOffsetMs)];
        }
    }

    if (!self.isVolumeScrubbing) {
        self.volumeSlider.value = (float)s.volume;
    }

    NSString *isPlaying = (s.state == HBPlexSessionStatePlaying) ? @"Pause" : @"Play";
    [self.playPauseButton setTitle:isPlaying forState:UIControlStateNormal];

    NSString *key = s.item.art ?: s.item.preferredThumbKey;
    if (key.length > 0 && ![key isEqualToString:self.currentArtKey]) {
        self.currentArtKey = key;
        CGSize size = CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height);
        [[HBPlexClient sharedClient] loadImageForThumbKey:key size:size completion:^(UIImage *img, NSError *e) {
            if ([key isEqualToString:self.currentArtKey]) {
                self.backdropView.image = img;
            }
        }];
        NSString *poster = s.item.preferredThumbKey;
        if (poster.length > 0) {
            [[HBPlexClient sharedClient] loadImageForThumbKey:poster size:CGSizeMake(200, 300) completion:^(UIImage *img, NSError *e) {
                self.artView.image = img;
            }];
        }
    }
}

- (NSString *)formatMs:(NSInteger)ms {
    NSInteger total = ms / 1000;
    NSInteger h = total / 3600;
    NSInteger m = (total % 3600) / 60;
    NSInteger s = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)h, (long)m, (long)s];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
}

- (void)autoDismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Seek

- (void)seekTouchDown { self.isSeekScrubbing = YES; }

- (void)seekChanged {
    NSInteger ms = (NSInteger)self.seekSlider.value;
    NSInteger duration = (NSInteger)self.seekSlider.maximumValue;
    self.elapsedLabel.text   = [self formatMs:ms];
    self.remainingLabel.text = [self formatMs:MAX(0, duration - ms)];
}

- (void)seekTouchUp {
    self.isSeekScrubbing = NO;
    NSInteger ms = (NSInteger)self.seekSlider.value;
    [[HBPlexClient sharedClient] seekToOffsetMs:ms completion:nil];
}

#pragma mark - Volume

- (void)volumeTouchDown { self.isVolumeScrubbing = YES; }

- (void)volumeTouchUp {
    self.isVolumeScrubbing = NO;
    [[HBPlexClient sharedClient] setVolume:(CGFloat)self.volumeSlider.value completion:nil];
}

#pragma mark - Transport

- (void)playPauseTapped { [[HBPlexClient sharedClient] playPauseWithCompletion:nil]; }
- (void)stopTapped      { [[HBPlexClient sharedClient] stopWithCompletion:nil]; }
- (void)prevTapped      { [[HBPlexClient sharedClient] skipPreviousWithCompletion:nil]; }
- (void)nextTapped      { [[HBPlexClient sharedClient] skipNextWithCompletion:nil]; }

#pragma mark - Streams

- (void)audioTapped {
    [self presentStreamSheetForStreams:self.session.audioStreams
                            selectedID:self.session.selectedAudioStreamID
                                 title:@"Audio"
                                 apply:^(NSString *sid) {
        [[HBPlexClient sharedClient] setAudioStreamID:sid completion:nil];
    }];
}

- (void)subtitlesTapped {
    [self presentStreamSheetForStreams:self.session.subtitleStreams
                            selectedID:self.session.selectedSubtitleStreamID
                                 title:@"Subtitles"
                                 apply:^(NSString *sid) {
        [[HBPlexClient sharedClient] setSubtitleStreamID:sid completion:nil];
    }];
}

- (void)presentStreamSheetForStreams:(NSArray<HBPlexStream *> *)streams
                          selectedID:(NSString *)selected
                               title:(NSString *)title
                               apply:(void (^)(NSString *sid))apply {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    if ([title isEqualToString:@"Subtitles"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Off"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            apply(nil);
        }]];
    }
    for (HBPlexStream *st in streams) {
        NSString *name = st.displayTitle.length ? st.displayTitle : (st.language.length ? st.language : @"Track");
        if (selected && [st.streamID isEqualToString:selected]) name = [NSString stringWithFormat:@"\u2713 %@", name];
        NSString *sid = st.streamID;
        [sheet addAction:[UIAlertAction actionWithTitle:name
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            apply(sid);
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
