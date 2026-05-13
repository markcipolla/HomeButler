#import "HBPlexRowView.h"
#import "HBPlexMediaCell.h"
#import "HBPlexItem.h"
#import "HBThemeManager.h"

static NSString * const kCellID = @"HBPlexMediaCell";

@interface HBPlexRowView () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *headerButton;
@property (nonatomic, strong) UICollectionView *collectionView;
@end

@implementation HBPlexRowView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        HBThemeManager *theme = [HBThemeManager sharedManager];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont boldSystemFontOfSize:18];
        _titleLabel.textColor = [theme textColor];
        [self addSubview:_titleLabel];

        _headerButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _headerButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_headerButton addTarget:self action:@selector(headerTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_headerButton];

        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.minimumLineSpacing = 12;
        layout.minimumInteritemSpacing = 12;
        layout.sectionInset = UIEdgeInsetsMake(0, 12, 0, 12);

        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.dataSource = self;
        _collectionView.delegate   = self;
        [_collectionView registerClass:[HBPlexMediaCell class] forCellWithReuseIdentifier:kCellID];
        [self addSubview:_collectionView];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor      constraintEqualToAnchor:self.topAnchor constant:8],
            [_titleLabel.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-12],

            [_headerButton.topAnchor      constraintEqualToAnchor:_titleLabel.topAnchor],
            [_headerButton.bottomAnchor   constraintEqualToAnchor:_titleLabel.bottomAnchor],
            [_headerButton.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
            [_headerButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

            [_collectionView.topAnchor      constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
            [_collectionView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
            [_collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_collectionView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)setTitle:(NSString *)title {
    _title = [title copy];
    self.titleLabel.text = title;
}

- (void)setItems:(NSArray *)items {
    _items = items;
    [self.collectionView reloadData];
}

- (void)headerTapped {
    if ([self.delegate respondsToSelector:@selector(plexRowViewDidTapHeader:)]) {
        [self.delegate plexRowViewDidTapHeader:self];
    }
}

#pragma mark - CollectionView

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    HBPlexMediaCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:ip];
    if (ip.item < (NSInteger)self.items.count) {
        [cell configureWithItem:self.items[ip.item]];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)ip {
    CGFloat h = cv.bounds.size.height - 4;
    CGFloat w = (h - 36) / 1.5; // 36 = title+subtitle area
    if (w < 80) w = 80;
    return CGSizeMake(w, h);
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    [cv deselectItemAtIndexPath:ip animated:YES];
    if (ip.item >= (NSInteger)self.items.count) return;
    HBPlexItem *item = self.items[ip.item];
    if ([self.delegate respondsToSelector:@selector(plexRowView:didTapItem:)]) {
        [self.delegate plexRowView:self didTapItem:item];
    }
}

@end
