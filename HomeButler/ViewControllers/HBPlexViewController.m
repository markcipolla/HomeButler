#import "HBPlexViewController.h"
#import "HBPlexLibraryViewController.h"
#import "HBPlexSearchViewController.h"
#import "HBPlexShowViewController.h"
#import "HBPlexDetailViewController.h"
#import "HBPlexNowPlayingViewController.h"
#import "HBPlexRowView.h"
#import "HBPlexNowPlayingPill.h"
#import "HBPlexClient.h"
#import "HBPlexItem.h"
#import "HBPlexSession.h"
#import "UIViewController+HBRefresh.h"
#import "HBThemeManager.h"

@interface HBPlexViewController () <UISearchBarDelegate, HBPlexRowViewDelegate, HBPlexNowPlayingPillDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) HBPlexRowView *onDeckRow;
@property (nonatomic, strong) HBPlexRowView *recentRow;
@property (nonatomic, strong) NSMutableArray<HBPlexRowView *> *sectionRows;
@property (nonatomic, strong) NSArray *sections; // raw section dicts
@property (nonatomic, strong) HBPlexNowPlayingPill *pill;
@property (nonatomic, assign) BOOL didLoadInitial;
@end

@implementation HBPlexViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Plex";
    self.view.backgroundColor = [[HBThemeManager sharedManager] backgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(closeTapped)];

    [self setupViews];
    [self hb_installPullToRefreshOnScrollView:self.scrollView];
    [self hb_installWakeRefreshObserver];
}

- (void)dealloc {
    [self hb_removeWakeRefreshObserver];
    [self hb_stopRefreshTimer];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.didLoadInitial) {
        self.didLoadInitial = YES;
        [self refreshFromSource:HBRefreshSourceManual];
    }
    [self hb_startRefreshTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self hb_stopRefreshTimer];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupViews {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.backgroundColor = [theme backgroundColor];
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.placeholder = @"Search Plex";
    self.searchBar.delegate = self;
    self.searchBar.barTintColor = [theme backgroundColor];
    self.searchBar.backgroundImage = [[UIImage alloc] init];
    [self.contentView addSubview:self.searchBar];

    self.onDeckRow = [self makeRowWithTitle:@"On Deck"];
    [self.contentView addSubview:self.onDeckRow];

    self.recentRow = [self makeRowWithTitle:@"Recently Added"];
    [self.contentView addSubview:self.recentRow];

    self.sectionRows = [NSMutableArray array];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor      constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor  constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor   constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor    constraintEqualToAnchor:self.scrollView.widthAnchor],

        [self.searchBar.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.searchBar.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],

        [self.onDeckRow.topAnchor      constraintEqualToAnchor:self.searchBar.bottomAnchor constant:8],
        [self.onDeckRow.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.onDeckRow.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.onDeckRow.heightAnchor   constraintEqualToConstant:260],

        [self.recentRow.topAnchor      constraintEqualToAnchor:self.onDeckRow.bottomAnchor constant:8],
        [self.recentRow.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.recentRow.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.recentRow.heightAnchor   constraintEqualToConstant:260],
    ]];

    // Now Playing pill, pinned above bottom
    self.pill = [[HBPlexNowPlayingPill alloc] init];
    self.pill.translatesAutoresizingMaskIntoConstraints = NO;
    self.pill.hidden = YES;
    self.pill.delegate = self;
    [self.view addSubview:self.pill];
    [NSLayoutConstraint activateConstraints:@[
        [self.pill.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.pill.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.pill.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor constant:-12],
        [self.pill.heightAnchor   constraintEqualToConstant:66],
    ]];
}

- (HBPlexRowView *)makeRowWithTitle:(NSString *)title {
    HBPlexRowView *row = [[HBPlexRowView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.title = title;
    row.delegate = self;
    return row;
}

#pragma mark - HBRefreshable

- (NSTimeInterval)refreshPollingInterval { return 5.0; }
- (BOOL)refreshShouldPollWhenVisible     { return YES; }

- (void)refreshFromSource:(HBRefreshSource)source {
    BOOL fullRefresh = (source == HBRefreshSourcePullToRefresh
                       || source == HBRefreshSourceWakeFromSleep
                       || source == HBRefreshSourceManual);
    if (fullRefresh) {
        [self loadSections];
    }
    [self loadOnDeck];
    [self loadRecentlyAdded];
    [self loadActiveSessions];
}

- (void)loadSections {
    __weak typeof(self) weakSelf = self;
    [[HBPlexClient sharedClient] fetchSectionsWithCompletion:^(NSArray<NSDictionary *> *sections, NSError *error) {
        __strong typeof(weakSelf) strong = weakSelf;
        if (!strong) return;
        if (error) { [strong hb_endRefreshing]; return; }
        strong.sections = sections;
        [strong rebuildSectionRows];
        [strong hb_endRefreshing];
    }];
}

- (void)rebuildSectionRows {
    UIView *previous = self.recentRow;
    NSInteger toReuse = MIN(self.sections.count, self.sectionRows.count);
    for (NSInteger i = 0; i < toReuse; i++) {
        HBPlexRowView *row = self.sectionRows[i];
        NSDictionary *sec = self.sections[i];
        row.title = sec[@"title"];
        row.sectionID = [sec[@"key"] description];
        [self loadItemsForSection:sec into:row];
        previous = row;
    }
    // Add new
    for (NSInteger i = toReuse; i < (NSInteger)self.sections.count; i++) {
        NSDictionary *sec = self.sections[i];
        HBPlexRowView *row = [self makeRowWithTitle:sec[@"title"]];
        row.sectionID = [sec[@"key"] description];
        [self.contentView addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.topAnchor      constraintEqualToAnchor:previous.bottomAnchor constant:8],
            [row.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [row.heightAnchor   constraintEqualToConstant:260],
        ]];
        [self.sectionRows addObject:row];
        [self loadItemsForSection:sec into:row];
        previous = row;
    }
    // Remove excess
    while (self.sectionRows.count > (NSUInteger)self.sections.count) {
        HBPlexRowView *r = self.sectionRows.lastObject;
        [r removeFromSuperview];
        [self.sectionRows removeLastObject];
    }
    // Anchor last row to contentView bottom
    if (previous && previous != self.recentRow) {
        [self.contentView.bottomAnchor constraintEqualToAnchor:previous.bottomAnchor constant:80].active = YES;
    }
}

- (void)loadItemsForSection:(NSDictionary *)sec into:(HBPlexRowView *)row {
    NSString *key = [sec[@"key"] description];
    [[HBPlexClient sharedClient] fetchItemsInSection:key sort:@"addedAt:desc" containerStart:0 containerSize:20 completion:^(NSArray *items, NSError *error) {
        if (items) [row setItems:items];
    }];
}

- (void)loadOnDeck {
    [[HBPlexClient sharedClient] fetchOnDeckWithCompletion:^(NSArray *items, NSError *err) {
        if (items) [self.onDeckRow setItems:items];
    }];
}

- (void)loadRecentlyAdded {
    [[HBPlexClient sharedClient] fetchRecentlyAddedWithCompletion:^(NSArray *items, NSError *err) {
        if (items) [self.recentRow setItems:items];
    }];
}

- (void)loadActiveSessions {
    [[HBPlexClient sharedClient] fetchActiveSessionsWithCompletion:^(NSArray *sessions, NSError *err) {
        HBPlexSession *active = sessions.firstObject;
        if (active) {
            self.pill.hidden = NO;
            [self.pill configureWithSession:active];
        } else {
            self.pill.hidden = YES;
        }
    }];
}

#pragma mark - HBPlexRowViewDelegate

- (void)plexRowView:(HBPlexRowView *)row didTapItem:(HBPlexItem *)item {
    UIViewController *next = nil;
    switch (item.type) {
        case HBPlexItemTypeShow:
            next = [[HBPlexShowViewController alloc] initWithItem:item mode:0];
            break;
        case HBPlexItemTypeSeason:
            next = [[HBPlexShowViewController alloc] initWithItem:item mode:1];
            break;
        case HBPlexItemTypeMovie:
        case HBPlexItemTypeEpisode:
        case HBPlexItemTypeClip:
        default:
            next = [[HBPlexDetailViewController alloc] initWithItem:item];
            break;
    }
    if (next) [self.navigationController pushViewController:next animated:YES];
}

- (void)plexRowViewDidTapHeader:(HBPlexRowView *)row {
    if (row.sectionID.length > 0) {
        HBPlexLibraryViewController *vc = [[HBPlexLibraryViewController alloc] initWithSectionID:row.sectionID title:row.title];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma mark - Pill

- (void)plexNowPlayingPillDidTap:(HBPlexNowPlayingPill *)pill {
    HBPlexNowPlayingViewController *vc = [[HBPlexNowPlayingViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    // No-op; user must press search button (avoids unneeded requests)
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    HBPlexSearchViewController *vc = [[HBPlexSearchViewController alloc] initWithQuery:@""];
    [self.navigationController pushViewController:vc animated:YES];
    return NO;
}

@end
