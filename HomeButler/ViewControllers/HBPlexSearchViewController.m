#import "HBPlexSearchViewController.h"
#import "HBPlexClient.h"
#import "HBPlexItem.h"
#import "HBPlexMediaCell.h"
#import "HBPlexDetailViewController.h"
#import "HBPlexShowViewController.h"
#import "UIViewController+HBRefresh.h"
#import "HBThemeManager.h"

static NSString * const kCellID = @"HBPlexMediaCell";

@interface HBPlexSearchViewController () <UISearchBarDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<HBPlexItem *> *results;
@property (nonatomic, copy)   NSString *pendingQuery;
@end

@implementation HBPlexSearchViewController

- (instancetype)initWithQuery:(NSString *)query {
    self = [super init];
    if (self) {
        _pendingQuery = [query copy];
        _results = @[];
        self.title = @"Search";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    HBThemeManager *theme = [HBThemeManager sharedManager];
    self.view.backgroundColor = [theme backgroundColor];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search Plex";
    self.searchBar.text = self.pendingQuery;
    self.searchBar.barStyle = UIBarStyleBlack;
    [self.view addSubview:self.searchBar];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 12;
    layout.minimumInteritemSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[HBPlexMediaCell class] forCellWithReuseIdentifier:kCellID];
    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [self.searchBar.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.collectionView.topAnchor      constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.collectionView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self hb_installPullToRefreshOnScrollView:self.collectionView];
    [self hb_installWakeRefreshObserver];

    if (self.pendingQuery.length > 0) {
        [self refreshFromSource:HBRefreshSourceManual];
    }
}

- (void)dealloc {
    [self hb_removeWakeRefreshObserver];
    [self hb_stopRefreshTimer];
}

#pragma mark - HBRefreshable

- (BOOL)refreshShouldPollWhenVisible { return NO; }

- (void)refreshFromSource:(HBRefreshSource)source {
    NSString *q = self.searchBar.text ?: self.pendingQuery;
    if (q.length == 0) { [self hb_endRefreshing]; self.results = @[]; [self.collectionView reloadData]; return; }
    [[HBPlexClient sharedClient] searchQuery:q completion:^(NSArray *items, NSError *error) {
        [self hb_endRefreshing];
        if (items) {
            self.results = items;
            [self.collectionView reloadData];
        }
    }];
}

#pragma mark - SearchBar (debounced)

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performDebouncedSearch) object:nil];
    [self performSelector:@selector(performDebouncedSearch) withObject:nil afterDelay:0.3];
}

- (void)performDebouncedSearch {
    [self refreshFromSource:HBRefreshSourceManual];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self refreshFromSource:HBRefreshSourceManual];
}

#pragma mark - CollectionView

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return self.results.count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    HBPlexMediaCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:ip];
    [cell configureWithItem:self.results[ip.item]];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)ip {
    BOOL portrait = cv.bounds.size.height > cv.bounds.size.width;
    NSInteger cols = portrait ? 3 : 5;
    CGFloat totalSpacing = 12 * (cols + 1);
    CGFloat w = (cv.bounds.size.width - totalSpacing) / cols;
    CGFloat h = w * 1.5 + 36;
    return CGSizeMake(w, h);
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    [cv deselectItemAtIndexPath:ip animated:YES];
    HBPlexItem *item = self.results[ip.item];
    UIViewController *next;
    if (item.type == HBPlexItemTypeShow) {
        next = [[HBPlexShowViewController alloc] initWithItem:item mode:0];
    } else if (item.type == HBPlexItemTypeSeason) {
        next = [[HBPlexShowViewController alloc] initWithItem:item mode:1];
    } else {
        next = [[HBPlexDetailViewController alloc] initWithItem:item];
    }
    [self.navigationController pushViewController:next animated:YES];
}

@end
