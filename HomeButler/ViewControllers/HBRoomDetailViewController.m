#import "HBRoomDetailViewController.h"
#import "HBRoom.h"
#import "HBThemeManager.h"
#import "HBLightToggleCell.h"
#import "HAEntity.h"
#import "HAAPIClient.h"
#import "HBAddRoomViewController.h"

@interface HBRoomDetailViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, HBLightToggleCellDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<HAEntity *> *roomEntities;
@property (nonatomic, strong) UIButton *allOnButton;
@property (nonatomic, strong) UIButton *allOffButton;

@end

@implementation HBRoomDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.room.name;

    HBThemeManager *theme = [HBThemeManager sharedManager];
    self.view.backgroundColor = [theme backgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Edit"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(editTapped)];

    [self setupCollectionView];
    [self setupControlButtons];
    [self filterRoomEntities];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = self.room.name;
    [self refreshEntities];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 16;
    layout.minimumLineSpacing = 16;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 100, 16);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.clipsToBounds = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[HBLightToggleCell class] forCellWithReuseIdentifier:@"LightCell"];
    [self.view addSubview:self.collectionView];
}

- (void)setupControlButtons {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    UIView *buttonContainer = [[UIView alloc] init];
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:buttonContainer];

    self.allOnButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.allOnButton.backgroundColor = [theme onColor];
    self.allOnButton.layer.cornerRadius = 25;
    [self.allOnButton setTitle:@"All On" forState:UIControlStateNormal];
    [self.allOnButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.allOnButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.allOnButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.allOnButton addTarget:self action:@selector(allOnTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.allOnButton];

    self.allOffButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.allOffButton.backgroundColor = [theme offColor];
    self.allOffButton.layer.cornerRadius = 25;
    [self.allOffButton setTitle:@"All Off" forState:UIControlStateNormal];
    [self.allOffButton setTitleColor:[theme textColor] forState:UIControlStateNormal];
    self.allOffButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.allOffButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.allOffButton addTarget:self action:@selector(allOffTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.allOffButton];

    [NSLayoutConstraint activateConstraints:@[
        [buttonContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [buttonContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-30],
        [buttonContainer.heightAnchor constraintEqualToConstant:50],

        [self.allOnButton.leadingAnchor constraintEqualToAnchor:buttonContainer.leadingAnchor],
        [self.allOnButton.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor],
        [self.allOnButton.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor],
        [self.allOnButton.widthAnchor constraintEqualToConstant:120],

        [self.allOffButton.leadingAnchor constraintEqualToAnchor:self.allOnButton.trailingAnchor constant:16],
        [self.allOffButton.trailingAnchor constraintEqualToAnchor:buttonContainer.trailingAnchor],
        [self.allOffButton.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor],
        [self.allOffButton.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor],
        [self.allOffButton.widthAnchor constraintEqualToConstant:120],
    ]];
}

- (void)filterRoomEntities {
    NSMutableArray *entities = [NSMutableArray array];
    for (NSString *entityId in self.room.entityIds) {
        for (HAEntity *entity in self.allEntities) {
            if ([entity.entityId isEqualToString:entityId]) {
                [entities addObject:entity];
                break;
            }
        }
    }
    self.roomEntities = entities;
    [self.collectionView reloadData];
}

- (void)refreshEntities {
    [[HAAPIClient sharedClient] fetchStatesWithCompletion:^(NSArray<HAEntity *> *entities, NSError *error) {
        if (!error) {
            self.allEntities = entities;
            [self filterRoomEntities];
        }
    }];
}

#pragma mark - Actions

- (void)editTapped {
    HBAddRoomViewController *editVC = [[HBAddRoomViewController alloc] init];
    editVC.room = self.room;
    editVC.allEntities = self.allEntities;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [[HBThemeManager sharedManager] applyThemeToNavigationBar:navController.navigationBar];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)allOnTapped {
    for (HAEntity *entity in self.roomEntities) {
        if (entity.entityType == HAEntityTypeLight && !entity.isOn) {
            [[HAAPIClient sharedClient] turnOnEntity:entity.entityId completion:nil];
        }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshEntities];
    });
}

- (void)allOffTapped {
    for (HAEntity *entity in self.roomEntities) {
        if (entity.entityType == HAEntityTypeLight && entity.isOn) {
            [[HAAPIClient sharedClient] turnOffEntity:entity.entityId completion:nil];
        }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshEntities];
    });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.roomEntities.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    HBLightToggleCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"LightCell" forIndexPath:indexPath];
    cell.delegate = self;
    [cell configureWithEntity:self.roomEntities[indexPath.item]];
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    // Square cells, 2 columns
    CGFloat cellSize = (self.view.bounds.size.width - 48) / 2;
    return CGSizeMake(cellSize, cellSize);
}

#pragma mark - HBLightToggleCellDelegate

- (void)lightToggleCell:(HBLightToggleCell *)cell didToggleEntity:(HAEntity *)entity toState:(BOOL)on {
    if (on) {
        [[HAAPIClient sharedClient] turnOnEntity:entity.entityId completion:^(BOOL success, id result, NSError *error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self refreshEntities];
            });
        }];
    } else {
        [[HAAPIClient sharedClient] turnOffEntity:entity.entityId completion:^(BOOL success, id result, NSError *error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self refreshEntities];
            });
        }];
    }
}

- (void)lightToggleCell:(HBLightToggleCell *)cell didSetBrightness:(NSInteger)brightness forEntity:(HAEntity *)entity {
    NSInteger haBrightness = (brightness * 255) / 100;

    [[HAAPIClient sharedClient] setLightBrightness:entity.entityId brightness:haBrightness completion:^(BOOL success, id result, NSError *error) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self refreshEntities];
        });
    }];
}

- (void)lightToggleCell:(HBLightToggleCell *)cell didTriggerScript:(HAEntity *)entity {
    // Use entityId from cell - it's always available even if entity was deallocated
    NSString *entityId = cell.entityId;
    NSLog(@"[RoomDetail] didTriggerScript called, entityId: %@", entityId);

    if (!entityId) {
        NSLog(@"[RoomDetail] entityId is nil, returning");
        return;
    }

    // Trigger the script - scripts use turn_on to execute
    [[HAAPIClient sharedClient] turnOnEntity:entityId completion:^(BOOL success, id result, NSError *error) {
        if (success) {
            NSLog(@"[RoomDetail] Script triggered successfully: %@", entityId);
        } else {
            NSLog(@"[RoomDetail] Script trigger failed: %@, error: %@", entityId, error);
        }
    }];
}

@end
