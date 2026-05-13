#import "HBPlexLibraryViewController.h"
#import "HBPlexMediaCell.h"
#import "HBPlexClient.h"
#import "HBPlexItem.h"
#import "HBPlexDetailViewController.h"
#import "HBPlexShowViewController.h"
#import "UIViewController+HBRefresh.h"
#import "HBThemeManager.h"

static NSString * const kCellID = @"HBPlexMediaCell";

@interface HBPlexLibraryViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, copy)   NSString *sectionID;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<HBPlexItem *> *items;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL exhausted;
@end

@implementation HBPlexLibraryViewController

- (instancetype)initWithSectionID:(NSString *)sectionID title:(NSString *)title {
    self = [super init];
    if (self) {
        _sectionID = [sectionID copy];
        _items = [NSMutableArray array];
        self.title = title;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[HBThemeManager sharedManager] backgroundColor];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 12;
    layout.minimumInteritemSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[HBPlexMediaCell class] forCellWithReuseIdentifier:kCellID];
    [self.view addSubview:self.collectionView];

    [self hb_installPullToRefreshOnScrollView:self.collectionView];
    [self hb_installWakeRefreshObserver];
}

- (void)dealloc {
    [self hb_removeWakeRefreshObserver];
    [self hb_stopRefreshTimer];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.items.count == 0) {
        [self refreshFromSource:HBRefreshSourceManual];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self hb_stopRefreshTimer];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark - HBRefreshable

- (NSTimeInterval)refreshPollingInterval     { return 0; }
- (BOOL)refreshShouldPollWhenVisible         { return NO; }

- (void)refreshFromSource:(HBRefreshSource)source {
    if (self.loading) { [self hb_endRefreshing]; return; }
    self.loading = YES;
    self.exhausted = NO;
    [self.items removeAllObjects];
    [self loadNextPageWithStart:0];
}

- (void)loadNextPageWithStart:(NSInteger)start {
    __weak typeof(self) weakSelf = self;
    [[HBPlexClient sharedClient] fetchItemsInSection:self.sectionID sort:@"addedAt:desc" containerStart:start containerSize:50 completion:^(NSArray *items, NSError *error) {
        __strong typeof(weakSelf) strong = weakSelf;
        if (!strong) return;
        strong.loading = NO;
        [strong hb_endRefreshing];
        if (error || items == nil) return;
        if (items.count == 0) { strong.exhausted = YES; return; }
        [strong.items addObjectsFromArray:items];
        [strong.collectionView reloadData];
    }];
}

#pragma mark - CollectionView

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    HBPlexMediaCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:ip];
    [cell configureWithItem:self.items[ip.item]];

    // Pagination trigger
    if (!self.loading && !self.exhausted && ip.item >= (NSInteger)self.items.count - 20) {
        self.loading = YES;
        [self loadNextPageWithStart:self.items.count];
    }
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
    HBPlexItem *item = self.items[ip.item];
    UIViewController *next;
    if (item.type == HBPlexItemTypeShow) {
        next = [[HBPlexShowViewController alloc] initWithItem:item mode:0];
    } else {
        next = [[HBPlexDetailViewController alloc] initWithItem:item];
    }
    [self.navigationController pushViewController:next animated:YES];
}

@end
