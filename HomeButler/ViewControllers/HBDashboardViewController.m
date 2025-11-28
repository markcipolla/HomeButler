#import "HBDashboardViewController.h"
#import "HBThemeManager.h"
#import "HBRoom.h"
#import "HAAPIClient.h"
#import "HAEntity.h"
#import "HBAddRoomViewController.h"
#import "SettingsViewController.h"
#import "HBLightToggleCell.h"
#import "HBIconView.h"
#import "HBActionButton.h"
#import <objc/runtime.h>

@interface HBDashboardViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, HBLightToggleCellDelegate, UITableViewDataSource, UITableViewDelegate>

// Bottom navigation bar
@property (nonatomic, strong) UIView *bottomNavBar;
@property (nonatomic, strong) UIButton *homeButton;
@property (nonatomic, strong) UICollectionView *roomsCollectionView;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *addRoomButton;

// Track if Home is selected
@property (nonatomic, assign) BOOL isHomeSelected;

// Main content area
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) HBActionButton *allOnButton;
@property (nonatomic, strong) HBActionButton *allOffButton;
@property (nonatomic, strong) HBActionButton *editRoomButton;
@property (nonatomic, strong) UICollectionView *entitiesCollectionView;

// Data
@property (nonatomic, strong) NSArray<HAEntity *> *allEntities;
@property (nonatomic, strong) HBRoom *selectedRoom;
@property (nonatomic, strong) NSArray<HAEntity *> *selectedRoomLights;
@property (nonatomic, assign) BOOL isLoadingEntities;

// Drag and drop reordering
@property (nonatomic, strong) UIView *draggedCellSnapshot;
@property (nonatomic, strong) NSIndexPath *draggedIndexPath;

// Weather (Home screen)
@property (nonatomic, strong) UIView *weatherView;
@property (nonatomic, strong) UIView *currentWeatherCard;
@property (nonatomic, strong) UIView *portraitWeatherBar;
@property (nonatomic, strong) UILabel *portraitTempLabel;
@property (nonatomic, strong) UILabel *portraitConditionLabel;
@property (nonatomic, strong) HBIconView *portraitWeatherIcon;
@property (nonatomic, strong) UILabel *currentTempLabel;
@property (nonatomic, strong) HBIconView *currentWeatherIcon;
@property (nonatomic, strong) UILabel *currentConditionLabel;
@property (nonatomic, strong) UILabel *currentMinMaxLabel;
@property (nonatomic, strong) UILabel *currentRainLabel;
@property (nonatomic, strong) UIScrollView *forecastScrollView;
@property (nonatomic, strong) NSArray *forecastData;
@property (nonatomic, strong) HAEntity *weatherEntity;
@property (nonatomic, strong) NSTimer *weatherRefreshTimer;
@property (nonatomic, strong) NSDate *lastWeatherFetch;
@property (nonatomic, strong) NSTimer *entityRefreshTimer;

// Home sensors panel (right side)
@property (nonatomic, strong) UIView *sensorsPanel;
@property (nonatomic, strong) HBActionButton *homeAllOnButton;
@property (nonatomic, strong) HBActionButton *homeAllOffButton;
@property (nonatomic, strong) HBActionButton *editHomeSensorsButton;
@property (nonatomic, strong) NSMutableArray<NSString *> *homeSensorIds;
@property (nonatomic, assign) BOOL isEditingHomeSensors;

// Home sensor drag reordering
@property (nonatomic, strong) UIView *draggingSensorView;
@property (nonatomic, assign) NSInteger draggingSensorIndex;
@property (nonatomic, assign) CGPoint dragStartCenter;
@property (nonatomic, strong) NSMutableArray<UIView *> *sensorCardViews;
@property (nonatomic, strong) NSMutableArray<NSValue *> *originalCardCenters;
@property (nonatomic, assign) NSInteger currentPreviewIndex;
@property (nonatomic, strong) UIView *dropPlaceholderView;
@property (nonatomic, strong) CAShapeLayer *dropPlaceholderBorder;

// Connection status overlay
@property (nonatomic, strong) UIView *connectionOverlay;
@property (nonatomic, strong) UIActivityIndicatorView *connectionSpinner;
@property (nonatomic, strong) UILabel *connectionLabel;

// Bin button for delete during drag
@property (nonatomic, strong) UIButton *binButton;
@property (nonatomic, strong) UIButton *homeBinButton;
@property (nonatomic, assign) BOOL isDraggingOverBin;
@property (nonatomic, assign) BOOL isHomeDraggingOverBin;
@property (nonatomic, strong) NSIndexPath *draggingRoomEntityIndexPath;
@property (nonatomic, assign) BOOL isDraggingEntity; // Prevents UI refresh during drag

@end

static const CGFloat kBottomNavHeight = 90.0;
static const CGFloat kRoomTileSize = 90.0;

@implementation HBDashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    HBThemeManager *theme = [HBThemeManager sharedManager];
    self.view.backgroundColor = [theme backgroundColor];

    self.navigationController.navigationBarHidden = YES;

    // Load saved home sensor IDs
    [self loadHomeSensorIds];

    [self setupBottomNavBar];
    [self setupContent];
    [self loadEntities];

    // Select first room by default
    if ([HBRoomManager sharedManager].rooms.count > 0) {
        self.selectedRoom = [HBRoomManager sharedManager].rooms[0];
    }

    // Start weather refresh timer (every hour)
    [self startWeatherRefreshTimer];

    // Load weather on app start
    [self loadWeatherDataIfNeeded];

    // Listen for room changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(roomDidChange:)
                                                 name:@"HBRoomDidChangeNotification"
                                               object:nil];

    // Listen for connection status changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionStatusChanged:)
                                                 name:HAAPIClientConnectionStatusChangedNotification
                                               object:nil];

    // Setup connection overlay (hidden initially)
    [self setupConnectionOverlay];

    // Start entity refresh timer (every 1 second)
    [self startEntityRefreshTimer];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // Re-layout home tab elements if on home tab
        if (self.isHomeSelected) {
            [self showWeatherView];
            [self showSensorsPanel];
        }
    } completion:nil];
}

- (void)startEntityRefreshTimer {
    [self.entityRefreshTimer invalidate];
    self.entityRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(entityRefreshTimerFired)
                                                             userInfo:nil
                                                              repeats:YES];
}

- (void)entityRefreshTimerFired {
    NSLog(@"[Dashboard] Entity refresh timer fired");
    [self loadEntities];
}

- (void)roomDidChange:(NSNotification *)notification {
    [self refreshRoomsAndEntities];
}

- (void)connectionStatusChanged:(NSNotification *)notification {
    BOOL connected = [notification.userInfo[@"connected"] boolValue];
    if (connected) {
        [self hideConnectionOverlay];
    } else {
        [self showConnectionOverlay];
    }
}

- (void)setupConnectionOverlay {
    self.connectionOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.connectionOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.connectionOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.connectionOverlay.hidden = YES;

    // Spinner
    self.connectionSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.connectionSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.connectionOverlay addSubview:self.connectionSpinner];

    // Label
    self.connectionLabel = [[UILabel alloc] init];
    self.connectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectionLabel.text = @"Connecting to Home Assistant...";
    self.connectionLabel.textColor = [UIColor whiteColor];
    self.connectionLabel.font = [UIFont systemFontOfSize:18];
    self.connectionLabel.textAlignment = NSTextAlignmentCenter;
    [self.connectionOverlay addSubview:self.connectionLabel];

    [self.view addSubview:self.connectionOverlay];

    [NSLayoutConstraint activateConstraints:@[
        [self.connectionSpinner.centerXAnchor constraintEqualToAnchor:self.connectionOverlay.centerXAnchor],
        [self.connectionSpinner.centerYAnchor constraintEqualToAnchor:self.connectionOverlay.centerYAnchor constant:-20],
        [self.connectionLabel.centerXAnchor constraintEqualToAnchor:self.connectionOverlay.centerXAnchor],
        [self.connectionLabel.topAnchor constraintEqualToAnchor:self.connectionSpinner.bottomAnchor constant:20],
        [self.connectionLabel.leadingAnchor constraintEqualToAnchor:self.connectionOverlay.leadingAnchor constant:20],
        [self.connectionLabel.trailingAnchor constraintEqualToAnchor:self.connectionOverlay.trailingAnchor constant:-20]
    ]];
}

- (void)showConnectionOverlay {
    self.connectionOverlay.hidden = NO;
    [self.connectionSpinner startAnimating];
    [self.view bringSubviewToFront:self.connectionOverlay];
}

- (void)hideConnectionOverlay {
    self.connectionOverlay.hidden = YES;
    [self.connectionSpinner stopAnimating];
}

- (void)loadHomeSensorIds {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"HomeSensorIds"];
    if (saved) {
        self.homeSensorIds = [saved mutableCopy];
    } else {
        self.homeSensorIds = [NSMutableArray array];
    }
}

- (void)saveHomeSensorIds {
    [[NSUserDefaults standardUserDefaults] setObject:self.homeSensorIds forKey:@"HomeSensorIds"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.weatherRefreshTimer invalidate];
    self.weatherRefreshTimer = nil;
    [self.entityRefreshTimer invalidate];
    self.entityRefreshTimer = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [self refreshRoomsAndEntities];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Refresh again in case a modal was dismissed
    [self refreshRoomsAndEntities];
}

- (void)refreshRoomsAndEntities {
    // Re-fetch the selected room from the manager to get updated properties
    if (self.selectedRoom) {
        HBRoom *updatedRoom = [[HBRoomManager sharedManager] roomWithId:self.selectedRoom.roomId];
        if (updatedRoom) {
            self.selectedRoom = updatedRoom;
        } else {
            // Room was deleted - select first available room
            self.selectedRoom = [HBRoomManager sharedManager].rooms.firstObject;
            self.isHomeSelected = NO;
        }
    }

    // If no room is selected but rooms exist, select the first one
    if (!self.selectedRoom && [HBRoomManager sharedManager].rooms.count > 0) {
        self.selectedRoom = [HBRoomManager sharedManager].rooms.firstObject;
        self.isHomeSelected = NO;
    }

    [self updateHomeButtonAppearance];
    [self.roomsCollectionView reloadData];
    [self loadEntities];
    [self updateSelectedRoomDisplay];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
}

#pragma mark - Setup Bottom Navigation Bar

- (void)setupBottomNavBar {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    // Bottom navigation bar container
    self.bottomNavBar = [[UIView alloc] init];
    self.bottomNavBar.backgroundColor = [theme secondaryBackgroundColor];
    self.bottomNavBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomNavBar];

    // Home button (far left)
    self.homeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.homeButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *homeIcon = [HBIconView imageWithIconType:HBIconTypeHouse size:CGSizeMake(40, 40) color:[theme textColor]];
    [self.homeButton setImage:homeIcon forState:UIControlStateNormal];
    self.homeButton.backgroundColor = [theme cardBackgroundColor];
    self.homeButton.layer.cornerRadius = 0;
    [self.homeButton addTarget:self action:@selector(homeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomNavBar addSubview:self.homeButton];

    // Settings button (gear icon) - square, no rounding
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *gearIcon = [HBIconView imageWithIconType:HBIconTypeGear size:CGSizeMake(36, 36) color:[theme textColor]];
    [self.settingsButton setImage:gearIcon forState:UIControlStateNormal];
    self.settingsButton.backgroundColor = [theme cardBackgroundColor];
    self.settingsButton.layer.cornerRadius = 0;
    [self.settingsButton addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomNavBar addSubview:self.settingsButton];

    // Add Room button (+ icon) - right side, square, no rounding
    self.addRoomButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.addRoomButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *plusIcon = [HBIconView imageWithIconType:HBIconTypePlus size:CGSizeMake(32, 32) color:[theme textColor]];
    [self.addRoomButton setImage:plusIcon forState:UIControlStateNormal];
    self.addRoomButton.backgroundColor = [theme accentColor];
    self.addRoomButton.layer.cornerRadius = 0;
    [self.addRoomButton addTarget:self action:@selector(addRoomTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomNavBar addSubview:self.addRoomButton];

    // Rooms collection view (horizontal scrolling, square tiles, no gaps)
    UICollectionViewFlowLayout *roomsLayout = [[UICollectionViewFlowLayout alloc] init];
    roomsLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    roomsLayout.minimumInteritemSpacing = 0;
    roomsLayout.minimumLineSpacing = 0;
    roomsLayout.itemSize = CGSizeMake(kRoomTileSize, kRoomTileSize);
    roomsLayout.sectionInset = UIEdgeInsetsZero;

    self.roomsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:roomsLayout];
    self.roomsCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.roomsCollectionView.backgroundColor = [UIColor clearColor];
    self.roomsCollectionView.showsHorizontalScrollIndicator = NO;
    self.roomsCollectionView.clipsToBounds = YES;
    self.roomsCollectionView.dataSource = self;
    self.roomsCollectionView.delegate = self;
    [self.roomsCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"RoomTileCell"];
    [self.bottomNavBar addSubview:self.roomsCollectionView];

    // Add long press gesture for reordering rooms
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self.roomsCollectionView addGestureRecognizer:longPress];

    [NSLayoutConstraint activateConstraints:@[
        // Bottom nav bar
        [self.bottomNavBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomNavBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomNavBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomNavBar.heightAnchor constraintEqualToConstant:kBottomNavHeight],

        // Home button (far left)
        [self.homeButton.leadingAnchor constraintEqualToAnchor:self.bottomNavBar.leadingAnchor],
        [self.homeButton.topAnchor constraintEqualToAnchor:self.bottomNavBar.topAnchor],
        [self.homeButton.bottomAnchor constraintEqualToAnchor:self.bottomNavBar.bottomAnchor],
        [self.homeButton.widthAnchor constraintEqualToConstant:kRoomTileSize],

        // Rooms collection view (between Home and Settings, clips overflow, scrolls horizontally)
        [self.roomsCollectionView.leadingAnchor constraintEqualToAnchor:self.homeButton.trailingAnchor],
        [self.roomsCollectionView.trailingAnchor constraintEqualToAnchor:self.settingsButton.leadingAnchor],
        [self.roomsCollectionView.topAnchor constraintEqualToAnchor:self.bottomNavBar.topAnchor],
        [self.roomsCollectionView.bottomAnchor constraintEqualToAnchor:self.bottomNavBar.bottomAnchor],

        // Settings button (to the left of + button)
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:self.addRoomButton.leadingAnchor],
        [self.settingsButton.topAnchor constraintEqualToAnchor:self.bottomNavBar.topAnchor],
        [self.settingsButton.bottomAnchor constraintEqualToAnchor:self.bottomNavBar.bottomAnchor],
        [self.settingsButton.widthAnchor constraintEqualToConstant:kRoomTileSize],

        // Add Room button (far right)
        [self.addRoomButton.trailingAnchor constraintEqualToAnchor:self.bottomNavBar.trailingAnchor],
        [self.addRoomButton.topAnchor constraintEqualToAnchor:self.bottomNavBar.topAnchor],
        [self.addRoomButton.bottomAnchor constraintEqualToAnchor:self.bottomNavBar.bottomAnchor],
        [self.addRoomButton.widthAnchor constraintEqualToConstant:kRoomTileSize],
    ]];
}

#pragma mark - Setup Content

- (void)setupContent {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    // Main content container (full width, above bottom nav)
    self.contentView = [[UIView alloc] init];
    self.contentView.backgroundColor = [theme backgroundColor];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.contentView];

    // All On button (top left)
    self.allOnButton = [HBActionButton textButtonWithTitle:@"All On"];
    [self.allOnButton addTarget:self action:@selector(allOnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.allOnButton];

    // All Off button (next to All On)
    self.allOffButton = [HBActionButton textButtonWithTitle:@"All Off"];
    [self.allOffButton addTarget:self action:@selector(allOffTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.allOffButton];

    // Edit Room button (top right, pencil icon)
    self.editRoomButton = [HBActionButton iconButtonWithType:HBIconTypePencil];
    [self.editRoomButton addTarget:self action:@selector(editRoomTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.editRoomButton];

    // Bin button (left of Edit, hidden initially, shows during drag)
    self.binButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.binButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.binButton.backgroundColor = [[HBThemeManager sharedManager] cardBackgroundColor];
    self.binButton.layer.cornerRadius = 25;
    self.binButton.layer.borderWidth = 3;
    self.binButton.layer.borderColor = [UIColor clearColor].CGColor;
    [self.binButton setTitle:@"🗑" forState:UIControlStateNormal];
    self.binButton.titleLabel.font = [UIFont systemFontOfSize:24];
    self.binButton.alpha = 0;
    self.binButton.hidden = YES;
    [self.contentView addSubview:self.binButton];

    // Entities collection view - dynamic columns with equal spacing (12pt)
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 12;
    layout.minimumLineSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(0, 12, 12, 12);

    self.entitiesCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.entitiesCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.entitiesCollectionView.backgroundColor = [UIColor clearColor];
    self.entitiesCollectionView.clipsToBounds = NO;
    self.entitiesCollectionView.dataSource = self;
    self.entitiesCollectionView.delegate = self;
    [self.entitiesCollectionView registerClass:[HBLightToggleCell class] forCellWithReuseIdentifier:@"LightCell"];
    [self.contentView addSubview:self.entitiesCollectionView];

    // Long-press gesture for reordering room entities
    UILongPressGestureRecognizer *roomLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleRoomEntityLongPress:)];
    roomLongPress.minimumPressDuration = 0.5;
    [self.entitiesCollectionView addGestureRecognizer:roomLongPress];

    [NSLayoutConstraint activateConstraints:@[
        // Content view (full width, from top to bottom nav)
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.bottomNavBar.topAnchor],

        // All On button (top left, with spacing from status bar)
        [self.allOnButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.allOnButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:32],

        // All Off button (next to All On)
        [self.allOffButton.leadingAnchor constraintEqualToAnchor:self.allOnButton.trailingAnchor constant:12],
        [self.allOffButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:32],

        // Edit Room button (top right)
        [self.editRoomButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.editRoomButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:32],

        // Bin button (left of Edit)
        [self.binButton.trailingAnchor constraintEqualToAnchor:self.editRoomButton.leadingAnchor constant:-12],
        [self.binButton.centerYAnchor constraintEqualToAnchor:self.editRoomButton.centerYAnchor],
        [self.binButton.widthAnchor constraintEqualToConstant:50],
        [self.binButton.heightAnchor constraintEqualToConstant:50],

        // Entities collection (below buttons)
        [self.entitiesCollectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.entitiesCollectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.entitiesCollectionView.topAnchor constraintEqualToAnchor:self.allOnButton.bottomAnchor constant:12],
        [self.entitiesCollectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
    ]];
}

#pragma mark - Data Loading

- (void)loadEntities {
    // Prevent multiple simultaneous loads
    if (self.isLoadingEntities) {
        return;
    }
    self.isLoadingEntities = YES;

    __weak typeof(self) weakSelf = self;
    [[HAAPIClient sharedClient] fetchStatesWithCompletion:^(NSArray<HAEntity *> *entities, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.isLoadingEntities = NO;

        if (!error && entities) {
            strongSelf.allEntities = entities;
            [strongSelf.roomsCollectionView reloadData];
            [strongSelf updateSelectedRoomDisplay];

            // Fetch weather data now that entities are loaded
            [strongSelf loadWeatherDataIfNeeded];
        }
    }];
}

- (void)updateSelectedRoomDisplay {
    NSLog(@"[Dashboard] updateSelectedRoomDisplay called");

    if (self.isHomeSelected) {
        // Home is selected - show weather view and sensors panel
        NSLog(@"[Dashboard] Home selected - showing weather view");
        self.selectedRoomLights = @[];
        self.allOnButton.hidden = YES;
        self.allOffButton.hidden = YES;
        self.editRoomButton.hidden = YES;
        self.entitiesCollectionView.hidden = YES;
        [self showWeatherView];
        [self showSensorsPanel];

        // Update UI with cached data if available, then check if refresh needed
        if (self.forecastData && self.forecastData.count > 0) {
            [self updateCurrentWeatherFromEntity];
            [self updateForecastView];
        }
        [self loadWeatherDataIfNeeded];
    } else if (!self.selectedRoom) {
        NSLog(@"[Dashboard] No selected room");
        self.selectedRoomLights = @[];
        self.allOnButton.hidden = YES;
        self.allOffButton.hidden = YES;
        self.editRoomButton.hidden = YES;
        self.entitiesCollectionView.hidden = YES;
        [self hideWeatherView];
    } else {
        NSLog(@"[Dashboard] Selected room: %@", self.selectedRoom.name);
        self.allOnButton.hidden = NO;
        self.allOffButton.hidden = NO;
        self.editRoomButton.hidden = NO;
        self.entitiesCollectionView.hidden = NO;
        [self hideWeatherView];

        // Get lights for selected room with defensive nil checks
        NSMutableArray<HAEntity *> *lights = [NSMutableArray array];
        NSArray *entityIds = self.selectedRoom.entityIds;
        NSArray *allEntities = self.allEntities;

        NSLog(@"[Dashboard] entityIds count: %lu, allEntities count: %lu",
              (unsigned long)(entityIds ? entityIds.count : 0),
              (unsigned long)(allEntities ? allEntities.count : 0));

        if (entityIds && allEntities) {
            for (NSString *entityId in entityIds) {
                if (!entityId) continue;
                for (HAEntity *entity in allEntities) {
                    if (!entity || !entity.entityId) continue;
                    // Include all supported entity types except cameras
                    if ([entity.entityId isEqualToString:entityId] &&
                        (entity.entityType == HAEntityTypeLight ||
                         entity.entityType == HAEntityTypeSwitch ||
                         entity.entityType == HAEntityTypeSensor ||
                         entity.entityType == HAEntityTypeBinarySensor ||
                         entity.entityType == HAEntityTypeScript ||
                         entity.entityType == HAEntityTypeInputBoolean ||
                         entity.entityType == HAEntityTypeVacuum ||
                         entity.entityType == HAEntityTypeButton ||
                         entity.entityType == HAEntityTypeFan ||
                         entity.entityType == HAEntityTypeClimate ||
                         entity.entityType == HAEntityTypeNumber ||
                         entity.entityType == HAEntityTypeSelect)) {
                        [lights addObject:entity];
                        break;
                    }
                }
            }
        }
        self.selectedRoomLights = [lights copy];
        NSLog(@"[Dashboard] selectedRoomLights count: %lu", (unsigned long)self.selectedRoomLights.count);
    }

    [self updateAllOnOffButtonStates];
    // Skip reload if dragging to prevent flickering
    if (!self.isDraggingEntity) {
        NSLog(@"[Dashboard] About to reload collection view");
        [self.entitiesCollectionView reloadData];
    }
    NSLog(@"[Dashboard] updateSelectedRoomDisplay done");
}

- (void)updateAllOnOffButtonStates {
    BOOL allOn = YES;
    BOOL allOff = YES;

    for (HAEntity *light in self.selectedRoomLights) {
        if (light.isOn) {
            allOff = NO;
        } else {
            allOn = NO;
        }
    }

    // If no lights, neither is highlighted
    if (self.selectedRoomLights.count == 0) {
        allOn = NO;
        allOff = NO;
    }

    // Update button states using the shared component
    [self.allOnButton setActive:allOn];
    [self.allOffButton setActive:allOff];
}

#pragma mark - Actions

- (void)homeTapped {
    self.isHomeSelected = YES;
    self.selectedRoom = nil;
    [self updateHomeButtonAppearance];
    [self.roomsCollectionView reloadData];
    [self updateSelectedRoomDisplay];
}

- (void)updateHomeButtonAppearance {
    HBThemeManager *theme = [HBThemeManager sharedManager];
    if (self.isHomeSelected) {
        self.homeButton.backgroundColor = [theme onColor];
        UIImage *homeIcon = [HBIconView imageWithIconType:HBIconTypeHouse size:CGSizeMake(40, 40) color:[UIColor blackColor]];
        [self.homeButton setImage:homeIcon forState:UIControlStateNormal];
    } else {
        self.homeButton.backgroundColor = [theme cardBackgroundColor];
        UIImage *homeIcon = [HBIconView imageWithIconType:HBIconTypeHouse size:CGSizeMake(40, 40) color:[theme textColor]];
        [self.homeButton setImage:homeIcon forState:UIControlStateNormal];
    }
}

- (void)settingsTapped {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    settingsVC.isInitialSetup = NO;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [[HBThemeManager sharedManager] applyThemeToNavigationBar:navController.navigationBar];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)addRoomTapped {
    HBAddRoomViewController *addVC = [[HBAddRoomViewController alloc] init];
    addVC.allEntities = self.allEntities;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:addVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [[HBThemeManager sharedManager] applyThemeToNavigationBar:navController.navigationBar];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)editRoomTapped {
    if (!self.selectedRoom) {
        return;
    }
    HBAddRoomViewController *editVC = [[HBAddRoomViewController alloc] init];
    editVC.room = self.selectedRoom;
    editVC.allEntities = self.allEntities;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [[HBThemeManager sharedManager] applyThemeToNavigationBar:navController.navigationBar];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)allOnTapped {
    [self toggleAllLights:YES];
}

- (void)allOffTapped {
    [self toggleAllLights:NO];
}

- (void)toggleAllLights:(BOOL)on {
    // Update local state immediately for responsive UI
    for (HAEntity *light in self.selectedRoomLights) {
        light.state = on ? @"on" : @"off";
    }
    [self.entitiesCollectionView reloadData];
    [self updateAllOnOffButtonStates];

    // Make API calls without callbacks to avoid stale entity access
    for (HAEntity *light in self.selectedRoomLights) {
        NSString *entityId = light.entityId;
        if (on) {
            [[HAAPIClient sharedClient] turnOnEntity:entityId completion:nil];
        } else {
            [[HAAPIClient sharedClient] turnOffEntity:entityId completion:nil];
        }
    }
}

- (void)homeAllOnTapped {
    [self toggleAllHomeLights:YES];
}

- (void)homeAllOffTapped {
    [self toggleAllHomeLights:NO];
}

- (void)toggleAllHomeLights:(BOOL)on {
    // Get all lights from all entities
    NSMutableArray<HAEntity *> *allLights = [NSMutableArray array];
    for (HAEntity *entity in self.allEntities) {
        if (entity.entityType == HAEntityTypeLight) {
            [allLights addObject:entity];
        }
    }

    // Update local state immediately for responsive UI
    for (HAEntity *light in allLights) {
        light.state = on ? @"on" : @"off";
    }

    // Update button states
    [self updateHomeAllOnOffButtonStates];

    // Make API calls
    for (HAEntity *light in allLights) {
        NSString *entityId = light.entityId;
        if (on) {
            [[HAAPIClient sharedClient] turnOnEntity:entityId completion:nil];
        } else {
            [[HAAPIClient sharedClient] turnOffEntity:entityId completion:nil];
        }
    }
}

- (void)updateHomeAllOnOffButtonStates {
    // Check if any light is on across all entities
    BOOL anyLightOn = NO;
    BOOL allLightsOn = YES;
    NSInteger lightCount = 0;

    for (HAEntity *entity in self.allEntities) {
        if (entity.entityType == HAEntityTypeLight) {
            lightCount++;
            if (entity.isOn) {
                anyLightOn = YES;
            } else {
                allLightsOn = NO;
            }
        }
    }

    // If no lights, neither is highlighted
    if (lightCount == 0) {
        allLightsOn = NO;
        anyLightOn = NO;
    }

    // All On is active only if ALL lights are on
    [self.homeAllOnButton setActive:allLightsOn];
    // All Off is active only if NO lights are on
    [self.homeAllOffButton setActive:!anyLightOn];
}

#pragma mark - Weather View

- (BOOL)isPortraitOrientation {
    CGFloat width = self.contentView.bounds.size.width;
    CGFloat height = self.contentView.bounds.size.height;
    return height > width;
}

- (void)showWeatherView {
    HBThemeManager *theme = [HBThemeManager sharedManager];
    CGFloat spacing = 12.0;
    BOOL isPortrait = [self isPortraitOrientation];

    // Calculate weather view frame based on orientation
    CGFloat weatherX, weatherY, weatherWidth, weatherHeight;

    if (isPortrait) {
        // Portrait: full width at bottom, current day + forecast side by side (50/50)
        weatherWidth = self.contentView.bounds.size.width;
        weatherHeight = 220;
        weatherX = 0;
        weatherY = self.contentView.bounds.size.height - weatherHeight - spacing;
    } else {
        // Landscape: left 50% of screen - current weather top half, forecast grid bottom half
        weatherWidth = self.contentView.bounds.size.width * 0.50;
        weatherHeight = self.contentView.bounds.size.height - 32 - spacing;
        weatherX = 0;
        weatherY = 32;
    }

    if (self.weatherView) {
        // Remove and recreate to ensure correct layout
        [self.weatherView removeFromSuperview];
        self.weatherView = nil;
        self.currentWeatherCard = nil;
        self.portraitWeatherBar = nil;
        self.forecastScrollView = nil;
    }

    self.weatherView = [[UIView alloc] initWithFrame:CGRectMake(weatherX, weatherY, weatherWidth, weatherHeight)];
    self.weatherView.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:self.weatherView];

    // === Landscape current weather card (left half) ===
    CGFloat halfWidth = (weatherWidth - spacing * 3) / 2; // spacing on left, middle, right
    self.currentWeatherCard = [[UIView alloc] initWithFrame:CGRectMake(spacing, 0, halfWidth, weatherHeight)];
    self.currentWeatherCard.backgroundColor = [theme cardBackgroundColor];
    self.currentWeatherCard.layer.cornerRadius = 12;
    [self.weatherView addSubview:self.currentWeatherCard];

    CGFloat iconSize = 70;
    CGFloat padding = 12;

    // Current temp (large) at top
    self.currentTempLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, padding, halfWidth - iconSize - padding * 2, 60)];
    self.currentTempLabel.text = @"--°";
    self.currentTempLabel.font = [UIFont systemFontOfSize:56 weight:UIFontWeightThin];
    self.currentTempLabel.textColor = [theme textColor];
    self.currentTempLabel.textAlignment = NSTextAlignmentLeft;
    self.currentTempLabel.adjustsFontSizeToFitWidth = YES;
    self.currentTempLabel.minimumScaleFactor = 0.5;
    [self.currentWeatherCard addSubview:self.currentTempLabel];

    // Weather icon (top right)
    self.currentWeatherIcon = [[HBIconView alloc] initWithIconType:HBIconTypeSun color:[theme textColor]];
    self.currentWeatherIcon.frame = CGRectMake(halfWidth - iconSize - padding, padding, iconSize, iconSize);
    [self.currentWeatherCard addSubview:self.currentWeatherIcon];

    // Min/Max temps below temp
    self.currentMinMaxLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 75, halfWidth - padding * 2, 26)];
    self.currentMinMaxLabel.text = @"";
    self.currentMinMaxLabel.textAlignment = NSTextAlignmentLeft;
    [self.currentWeatherCard addSubview:self.currentMinMaxLabel];

    // Current condition
    self.currentConditionLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 105, halfWidth - padding * 2, 24)];
    self.currentConditionLabel.text = @"Loading...";
    self.currentConditionLabel.font = [UIFont systemFontOfSize:18];
    self.currentConditionLabel.textColor = [theme secondaryTextColor];
    self.currentConditionLabel.textAlignment = NSTextAlignmentLeft;
    [self.currentWeatherCard addSubview:self.currentConditionLabel];

    // Rain amount
    self.currentRainLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 130, halfWidth - padding * 2, 24)];
    self.currentRainLabel.text = @"";
    self.currentRainLabel.font = [UIFont systemFontOfSize:18];
    self.currentRainLabel.textColor = [UIColor colorWithRed:0.4 green:0.6 blue:1.0 alpha:1.0];
    self.currentRainLabel.textAlignment = NSTextAlignmentLeft;
    [self.currentWeatherCard addSubview:self.currentRainLabel];

    // === Portrait current weather bar (condensed horizontal) ===
    CGFloat barHeight = 60;
    self.portraitWeatherBar = [[UIView alloc] initWithFrame:CGRectMake(spacing, 0, weatherWidth - spacing * 2, barHeight)];
    self.portraitWeatherBar.backgroundColor = [theme cardBackgroundColor];
    self.portraitWeatherBar.layer.cornerRadius = 12;
    self.portraitWeatherBar.hidden = YES;
    [self.weatherView addSubview:self.portraitWeatherBar];

    // Portrait: temp on left
    self.portraitTempLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, 100, 44)];
    self.portraitTempLabel.text = @"--°";
    self.portraitTempLabel.font = [UIFont systemFontOfSize:40 weight:UIFontWeightThin];
    self.portraitTempLabel.textColor = [theme textColor];
    self.portraitTempLabel.adjustsFontSizeToFitWidth = YES;
    [self.portraitWeatherBar addSubview:self.portraitTempLabel];

    // Portrait: condition in middle
    CGFloat barWidth = weatherWidth - spacing * 2;
    self.portraitConditionLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 8, barWidth - 180, 44)];
    self.portraitConditionLabel.text = @"Loading...";
    self.portraitConditionLabel.font = [UIFont systemFontOfSize:18];
    self.portraitConditionLabel.textColor = [theme secondaryTextColor];
    self.portraitConditionLabel.textAlignment = NSTextAlignmentCenter;
    self.portraitConditionLabel.adjustsFontSizeToFitWidth = YES;
    [self.portraitWeatherBar addSubview:self.portraitConditionLabel];

    // Portrait: icon on right
    CGFloat portraitIconSize = 44;
    self.portraitWeatherIcon = [[HBIconView alloc] initWithIconType:HBIconTypeSun color:[theme textColor]];
    self.portraitWeatherIcon.frame = CGRectMake(barWidth - portraitIconSize - 12, (barHeight - portraitIconSize) / 2, portraitIconSize, portraitIconSize);
    [self.portraitWeatherBar addSubview:self.portraitWeatherIcon];

    // === Forecast container (right half in landscape, below bar in portrait) ===
    CGFloat forecastX = isPortrait ? 0 : (spacing + halfWidth + spacing);
    CGFloat forecastY = isPortrait ? (barHeight + spacing) : 0;
    CGFloat forecastWidth = isPortrait ? weatherWidth : halfWidth;
    CGFloat forecastHeight = isPortrait ? (weatherHeight - barHeight - spacing) : weatherHeight;
    self.forecastScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(forecastX, forecastY, forecastWidth, forecastHeight)];
    self.forecastScrollView.showsHorizontalScrollIndicator = NO;
    self.forecastScrollView.scrollEnabled = NO;
    self.forecastScrollView.backgroundColor = [UIColor clearColor];
    [self.weatherView addSubview:self.forecastScrollView];

    // Apply portrait/landscape visibility
    [self updateWeatherLayoutForPortrait:isPortrait];
}

- (void)updateWeatherLayoutForPortrait:(BOOL)isPortrait {
    CGFloat weatherWidth = self.weatherView.bounds.size.width;
    CGFloat weatherHeight = self.weatherView.bounds.size.height;
    CGFloat spacing = 12.0;

    // Always show currentWeatherCard, hide portraitWeatherBar (no longer used)
    self.currentWeatherCard.hidden = NO;
    self.portraitWeatherBar.hidden = YES;

    // Update current weather card and forecast positions based on orientation
    CGFloat cardX, cardY, cardWidth, cardHeight;
    CGFloat forecastX, forecastY, forecastWidth, forecastHeight;

    if (isPortrait) {
        // Portrait: side-by-side layout (current weather left half, forecast right half)
        CGFloat halfWidth = (weatherWidth - spacing * 3) / 2;
        cardX = spacing;
        cardY = 0;
        cardWidth = halfWidth;
        cardHeight = weatherHeight;

        forecastX = spacing + halfWidth + spacing;
        forecastY = 0;
        forecastWidth = halfWidth;
        forecastHeight = weatherHeight;
    } else {
        // Landscape: stacked layout (current weather top half, forecast bottom half)
        CGFloat halfHeight = (weatherHeight - spacing) / 2;
        cardX = spacing;
        cardY = 0;
        cardWidth = weatherWidth - spacing * 2;
        cardHeight = halfHeight;

        forecastX = 0;
        forecastY = halfHeight + spacing;
        forecastWidth = weatherWidth;
        forecastHeight = halfHeight;
    }

    self.currentWeatherCard.frame = CGRectMake(cardX, cardY, cardWidth, cardHeight);
    self.forecastScrollView.frame = CGRectMake(forecastX, forecastY, forecastWidth, forecastHeight);

    // Update labels inside currentWeatherCard based on new card size
    CGFloat padding = 12;
    CGFloat iconSize = isPortrait ? 50 : 70;
    CGFloat tempFontSize = isPortrait ? 40 : 56;
    CGFloat labelFontSize = isPortrait ? 14 : 18;

    // Temp label
    self.currentTempLabel.frame = CGRectMake(padding, padding, cardWidth - iconSize - padding * 3, isPortrait ? 44 : 60);
    self.currentTempLabel.font = [UIFont systemFontOfSize:tempFontSize weight:UIFontWeightThin];

    // Weather icon (top right)
    self.currentWeatherIcon.frame = CGRectMake(cardWidth - iconSize - padding, padding, iconSize, iconSize);

    // Vertical layout for remaining labels
    CGFloat yPos = isPortrait ? 60 : 75;
    CGFloat labelHeight = isPortrait ? 20 : 26;

    // Min/Max temps
    self.currentMinMaxLabel.frame = CGRectMake(padding, yPos, cardWidth - padding * 2, labelHeight);
    yPos += labelHeight + 2;

    // Condition
    self.currentConditionLabel.frame = CGRectMake(padding, yPos, cardWidth - padding * 2, labelHeight);
    self.currentConditionLabel.font = [UIFont systemFontOfSize:labelFontSize];
    yPos += labelHeight + 2;

    // Rain
    self.currentRainLabel.frame = CGRectMake(padding, yPos, cardWidth - padding * 2, labelHeight);
    self.currentRainLabel.font = [UIFont systemFontOfSize:labelFontSize];

    // Re-layout forecast cards if data exists
    if (self.forecastData && self.forecastData.count > 0) {
        [self updateForecastView];
    }
}

- (void)hideWeatherView {
    if (self.weatherView) {
        self.weatherView.hidden = YES;
    }
    if (self.sensorsPanel) {
        self.sensorsPanel.hidden = YES;
    }
}

#pragma mark - Home Sensors Panel

- (void)showSensorsPanel {
    CGFloat spacing = 12.0;
    BOOL isPortrait = [self isPortraitOrientation];

    // Calculate panel frame based on orientation
    CGFloat panelX, panelY, panelWidth, panelHeight;

    if (isPortrait) {
        // Portrait: full width, from top to above weather area
        CGFloat weatherHeight = 220; // Match showWeatherView
        panelX = 0;
        panelY = 32;
        panelWidth = self.contentView.bounds.size.width;
        panelHeight = self.contentView.bounds.size.height - 32 - weatherHeight - spacing * 2;
    } else {
        // Landscape: right 50% of screen (weather is left 50%)
        CGFloat weatherWidth = self.contentView.bounds.size.width * 0.50;
        panelX = weatherWidth;
        panelY = 32;
        panelWidth = self.contentView.bounds.size.width - weatherWidth;
        panelHeight = self.contentView.bounds.size.height - 32 - spacing;
    }

    if (!self.sensorsPanel) {
        self.sensorsPanel = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelWidth, panelHeight)];
        self.sensorsPanel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:self.sensorsPanel];

        // Home All On button (top left of panel)
        self.homeAllOnButton = [HBActionButton textButtonWithTitle:@"All On"];
        self.homeAllOnButton.translatesAutoresizingMaskIntoConstraints = YES;
        self.homeAllOnButton.frame = CGRectMake(spacing, 0, 100, 50);
        [self.homeAllOnButton addTarget:self action:@selector(homeAllOnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.sensorsPanel addSubview:self.homeAllOnButton];

        // Home All Off button (next to All On)
        self.homeAllOffButton = [HBActionButton textButtonWithTitle:@"All Off"];
        self.homeAllOffButton.translatesAutoresizingMaskIntoConstraints = YES;
        self.homeAllOffButton.frame = CGRectMake(spacing + 100 + spacing, 0, 100, 50);
        [self.homeAllOffButton addTarget:self action:@selector(homeAllOffTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.sensorsPanel addSubview:self.homeAllOffButton];

        // Edit button (top right of panel)
        self.editHomeSensorsButton = [HBActionButton iconButtonWithType:HBIconTypePencil];
        self.editHomeSensorsButton.translatesAutoresizingMaskIntoConstraints = YES;
        [self.editHomeSensorsButton addTarget:self action:@selector(editHomeSensorsTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.sensorsPanel addSubview:self.editHomeSensorsButton];

        // Home Bin button (left of Edit, hidden initially)
        self.homeBinButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.homeBinButton.backgroundColor = [[HBThemeManager sharedManager] cardBackgroundColor];
        self.homeBinButton.layer.cornerRadius = 25;
        self.homeBinButton.layer.borderWidth = 3;
        self.homeBinButton.layer.borderColor = [UIColor clearColor].CGColor;
        [self.homeBinButton setTitle:@"🗑" forState:UIControlStateNormal];
        self.homeBinButton.titleLabel.font = [UIFont systemFontOfSize:24];
        self.homeBinButton.alpha = 0;
        self.homeBinButton.hidden = YES;
        [self.sensorsPanel addSubview:self.homeBinButton];
    }

    // Update frame for orientation change
    self.sensorsPanel.frame = CGRectMake(panelX, panelY, panelWidth, panelHeight);

    // Update button positions - align with entity grid (sidePadding is 0 in landscape, spacing in portrait)
    CGFloat buttonLeftPadding = isPortrait ? spacing : 0;
    self.homeAllOnButton.frame = CGRectMake(buttonLeftPadding, 0, 100, 50);
    self.homeAllOffButton.frame = CGRectMake(buttonLeftPadding + 100 + spacing, 0, 100, 50);

    // Update edit button position (depends on panel width)
    self.editHomeSensorsButton.frame = CGRectMake(panelWidth - spacing - 50, 0, 50, 50);
    // Update home bin button position (left of edit button)
    self.homeBinButton.frame = CGRectMake(panelWidth - spacing - 50 - spacing - 50, 0, 50, 50);

    self.sensorsPanel.hidden = NO;
    // Skip sensor panel update if dragging to prevent flickering
    if (!self.isDraggingEntity) {
        [self updateSensorsPanel];
    }
    [self updateHomeAllOnOffButtonStates];
}

- (void)updateSensorsPanel {
    HBThemeManager *theme = [HBThemeManager sharedManager];
    BOOL isPortrait = [self isPortraitOrientation];

    // Remove existing sensor views (but keep action buttons)
    for (UIView *subview in [self.sensorsPanel.subviews copy]) {
        if (subview != self.editHomeSensorsButton &&
            subview != self.homeAllOnButton &&
            subview != self.homeAllOffButton) {
            [subview removeFromSuperview];
        }
    }

    // Reset sensor card views array
    self.sensorCardViews = [NSMutableArray array];

    CGFloat spacing = 12.0;
    CGFloat panelWidth = self.sensorsPanel.bounds.size.width;
    CGFloat panelHeight = self.sensorsPanel.bounds.size.height;
    CGFloat topOffset = 50 + spacing; // Below action buttons

    // Grid layout: more columns in portrait (full width), fewer in landscape
    NSInteger columns = isPortrait ? 4 : 2;
    CGFloat sidePadding = isPortrait ? spacing : 0;
    CGFloat availableWidth = panelWidth - sidePadding - spacing;
    CGFloat availableHeight = panelHeight - topOffset;

    // Calculate card width with proper spacing
    CGFloat cardWidth = (availableWidth - (spacing * (columns - 1))) / columns;

    if (self.homeSensorIds.count == 0) {
        // Show placeholder message
        UILabel *placeholder = [[UILabel alloc] initWithFrame:CGRectMake(sidePadding, topOffset, availableWidth, 60)];
        placeholder.text = @"Tap the pencil to add entities";
        placeholder.font = [UIFont systemFontOfSize:14];
        placeholder.textColor = [theme secondaryTextColor];
        placeholder.textAlignment = NSTextAlignmentCenter;
        placeholder.numberOfLines = 0;
        [self.sensorsPanel addSubview:placeholder];
        return;
    }

    // Max 10 entities
    NSInteger maxItems = MIN(self.homeSensorIds.count, 10);

    // Calculate rows needed
    NSInteger rowsNeeded = (maxItems + columns - 1) / columns; // Ceiling division

    // Calculate card height to fit all rows in available space
    CGFloat cardHeight = (availableHeight - (spacing * (rowsNeeded - 1))) / rowsNeeded;

    // Don't let cards get taller than they are wide (keep square or shorter)
    if (cardHeight > cardWidth) {
        cardHeight = cardWidth;
    }

    for (NSInteger i = 0; i < maxItems; i++) {
        NSString *entityId = self.homeSensorIds[i];

        // Find entity
        HAEntity *entity = nil;
        for (HAEntity *e in self.allEntities) {
            if ([e.entityId isEqualToString:entityId]) {
                entity = e;
                break;
            }
        }

        if (!entity) continue;

        // Calculate grid position
        NSInteger row = i / columns;
        NSInteger col = i % columns;
        CGFloat xPos = sidePadding + col * (cardWidth + spacing);
        CGFloat yPos = topOffset + row * (cardHeight + spacing);

        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(xPos, yPos, cardWidth, cardHeight)];
        card.backgroundColor = [theme cardBackgroundColor];
        card.layer.cornerRadius = 12;
        card.tag = i; // Store index for reordering
        [self.sensorsPanel addSubview:card];
        [self.sensorCardViews addObject:card];

        // Add long-press gesture for reordering
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHomeSensorLongPress:)];
        longPress.minimumPressDuration = 0.5;
        [card addGestureRecognizer:longPress];

        // Adjust font sizes based on card height
        CGFloat nameFontSize = cardHeight > 80 ? 22 : (cardHeight > 60 ? 18 : 14);
        CGFloat valueFontSize = cardHeight > 80 ? 26 : (cardHeight > 60 ? 22 : 16);
        CGFloat padding = 8;

        // Entity name (top left, larger, wrapping) - use sizeToFit for proper top alignment
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, padding, cardWidth - padding * 2, 50)];
        nameLabel.text = entity.friendlyName;
        nameLabel.font = [UIFont boldSystemFontOfSize:nameFontSize];
        nameLabel.textColor = [theme textColor];
        nameLabel.textAlignment = NSTextAlignmentLeft;
        nameLabel.numberOfLines = 2;
        nameLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [nameLabel sizeToFit];
        // Reset x position after sizeToFit
        CGRect nameFrame = nameLabel.frame;
        nameFrame.origin.x = padding;
        nameFrame.origin.y = padding;
        nameFrame.size.width = MIN(nameFrame.size.width, cardWidth - padding * 2);
        nameLabel.frame = nameFrame;
        [card addSubview:nameLabel];

        // Entity value (bottom right, right aligned)
        CGFloat valueHeight = 36;
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, cardHeight - valueHeight - padding, cardWidth - padding * 2, valueHeight)];
        NSString *unit = entity.attributes[@"unit_of_measurement"] ?: @"";
        valueLabel.text = [NSString stringWithFormat:@"%@%@", entity.state, unit.length > 0 ? [NSString stringWithFormat:@" %@", unit] : @""];
        valueLabel.font = [UIFont systemFontOfSize:valueFontSize weight:UIFontWeightMedium];
        valueLabel.textColor = [theme secondaryTextColor];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.adjustsFontSizeToFitWidth = YES;
        valueLabel.minimumScaleFactor = 0.5;
        valueLabel.numberOfLines = 1;
        [card addSubview:valueLabel];
    }
}

- (void)editHomeSensorsTapped {
    [self showEntityPicker];
}

- (void)showEntityPicker {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    // Get all displayable entities (all known types except cameras and unknown)
    NSMutableArray<HAEntity *> *allDisplayableEntities = [NSMutableArray array];
    for (HAEntity *entity in self.allEntities) {
        if (entity.entityType != HAEntityTypeUnknown &&
            entity.entityType != HAEntityTypeCamera) {
            [allDisplayableEntities addObject:entity];
        }
    }

    // Sort by friendly name
    [allDisplayableEntities sortUsingComparator:^NSComparisonResult(HAEntity *a, HAEntity *b) {
        return [a.friendlyName compare:b.friendlyName options:NSCaseInsensitiveSearch];
    }];

    // Present a picker view controller
    UIViewController *pickerVC = [[UIViewController alloc] init];
    pickerVC.title = @"Select Entities";
    pickerVC.view.backgroundColor = [theme backgroundColor];

    // Search bar at top
    UITextField *searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, 70, pickerVC.view.bounds.size.width - 32, 40)];
    searchField.backgroundColor = [theme cardBackgroundColor];
    searchField.textColor = [theme textColor];
    searchField.layer.cornerRadius = 8;
    searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
    searchField.leftViewMode = UITextFieldViewModeAlways;
    searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Search entities..."
                                                                        attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:100/255.0 green:100/255.0 blue:105/255.0 alpha:1.0]}];
    searchField.returnKeyType = UIReturnKeySearch;
    searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    searchField.tag = 2001;
    [searchField addTarget:self action:@selector(entityPickerSearchChanged:) forControlEvents:UIControlEventEditingChanged];
    [pickerVC.view addSubview:searchField];

    // Table view below search
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 118, pickerVC.view.bounds.size.width, pickerVC.view.bounds.size.height - 118) style:UITableViewStylePlain];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.backgroundColor = [theme backgroundColor];
    tableView.separatorColor = [theme separatorColor];
    tableView.allowsMultipleSelection = YES;
    tableView.tag = 1001;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [pickerVC.view addSubview:tableView];

    // Store data for table view
    objc_setAssociatedObject(pickerVC, "allEntities", allDisplayableEntities, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pickerVC, "filteredEntities", [allDisplayableEntities mutableCopy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pickerVC, "tableView", tableView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pickerVC, "searchField", searchField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    tableView.dataSource = self;
    tableView.delegate = self;

    // Pre-select existing entities
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<HAEntity *> *filtered = objc_getAssociatedObject(pickerVC, "filteredEntities");
        for (NSInteger i = 0; i < filtered.count; i++) {
            HAEntity *entity = filtered[i];
            if ([self.homeSensorIds containsObject:entity.entityId]) {
                [tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
    });

    // Navigation buttons
    pickerVC.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(sensorPickerCancelled)];
    pickerVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                               target:self
                                                                                               action:@selector(sensorPickerDone)];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:pickerVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [theme applyThemeToNavigationBar:navController.navigationBar];

    // Store reference for later
    objc_setAssociatedObject(self, "sensorPickerVC", pickerVC, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self presentViewController:navController animated:YES completion:nil];
}

- (void)entityPickerSearchChanged:(UITextField *)searchField {
    UIViewController *pickerVC = objc_getAssociatedObject(self, "sensorPickerVC");
    NSArray<HAEntity *> *allEntities = objc_getAssociatedObject(pickerVC, "allEntities");
    UITableView *tableView = objc_getAssociatedObject(pickerVC, "tableView");

    NSString *searchText = searchField.text ?: @"";

    NSMutableArray<HAEntity *> *filtered = [NSMutableArray array];

    if (searchText.length == 0) {
        [filtered addObjectsFromArray:allEntities];
    } else {
        NSString *searchLower = [searchText lowercaseString];
        for (HAEntity *entity in allEntities) {
            NSString *nameLower = [entity.friendlyName lowercaseString];
            NSString *idLower = [entity.entityId lowercaseString];
            NSString *areaLower = [entity.areaName lowercaseString] ?: @"";

            if ([nameLower containsString:searchLower] ||
                [idLower containsString:searchLower] ||
                [areaLower containsString:searchLower]) {
                [filtered addObject:entity];
            }
        }
    }

    objc_setAssociatedObject(pickerVC, "filteredEntities", filtered, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tableView reloadData];

    // Re-select previously selected entities
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSInteger i = 0; i < filtered.count; i++) {
            HAEntity *entity = filtered[i];
            if ([self.homeSensorIds containsObject:entity.entityId]) {
                [tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
    });
}

- (void)sensorPickerCancelled {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sensorPickerDone {
    UIViewController *pickerVC = objc_getAssociatedObject(self, "sensorPickerVC");
    UITableView *tableView = objc_getAssociatedObject(pickerVC, "tableView");
    NSArray<HAEntity *> *filteredEntities = objc_getAssociatedObject(pickerVC, "filteredEntities");

    // Get selected entities from visible (filtered) list
    NSArray *selectedPaths = [tableView indexPathsForSelectedRows];
    NSMutableSet *selectedIds = [NSMutableSet setWithArray:self.homeSensorIds];

    // First, remove any that were in filtered list but not selected
    for (HAEntity *entity in filteredEntities) {
        [selectedIds removeObject:entity.entityId];
    }

    // Then add back the selected ones
    for (NSIndexPath *path in selectedPaths) {
        if (path.row < (NSInteger)filteredEntities.count) {
            HAEntity *entity = filteredEntities[path.row];
            [selectedIds addObject:entity.entityId];
        }
    }

    // Update homeSensorIds preserving order for entities that were already there
    NSMutableArray *newIds = [NSMutableArray array];
    // First add existing ones that are still selected
    for (NSString *existingId in self.homeSensorIds) {
        if ([selectedIds containsObject:existingId]) {
            [newIds addObject:existingId];
        }
    }
    // Then add new ones
    for (NSString *selectedId in selectedIds) {
        if (![newIds containsObject:selectedId]) {
            [newIds addObject:selectedId];
        }
    }

    // Limit to max 10 entities
    if (newIds.count > 10) {
        newIds = [[newIds subarrayWithRange:NSMakeRange(0, 10)] mutableCopy];
    }

    self.homeSensorIds = newIds;
    [self saveHomeSensorIds];
    [self updateSensorsPanel];

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Entity Picker TableView DataSource/Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView.tag == 1001) {
        UIViewController *pickerVC = objc_getAssociatedObject(self, "sensorPickerVC");
        NSArray *filteredEntities = objc_getAssociatedObject(pickerVC, "filteredEntities");
        return filteredEntities.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 1001) {
        static NSString *cellId = @"EntityPickerCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        }

        HBThemeManager *theme = [HBThemeManager sharedManager];
        UIViewController *pickerVC = objc_getAssociatedObject(self, "sensorPickerVC");
        NSArray<HAEntity *> *filteredEntities = objc_getAssociatedObject(pickerVC, "filteredEntities");

        if (indexPath.row >= (NSInteger)filteredEntities.count) {
            return cell;
        }

        HAEntity *entity = filteredEntities[indexPath.row];

        cell.backgroundColor = [theme cardBackgroundColor];
        cell.textLabel.text = entity.friendlyName;
        cell.textLabel.textColor = [theme textColor];

        // Show type, value, and entity ID
        NSString *typeStr = [self entityTypeString:entity.entityType];
        NSString *unit = entity.attributes[@"unit_of_measurement"] ?: @"";
        NSString *stateStr = [NSString stringWithFormat:@"%@%@", entity.state, unit.length > 0 ? [NSString stringWithFormat:@" %@", unit] : @""];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@ · %@", typeStr, stateStr, entity.entityId];
        cell.detailTextLabel.textColor = [theme secondaryTextColor];

        cell.tintColor = [theme accentColor];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

        // Show checkmark for selected cells
        BOOL isSelected = [self.homeSensorIds containsObject:entity.entityId];
        cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

        return cell;
    }
    return [[UITableViewCell alloc] init];
}

- (NSString *)entityTypeString:(HAEntityType)type {
    switch (type) {
        case HAEntityTypeLight: return @"Light";
        case HAEntityTypeSwitch: return @"Switch";
        case HAEntityTypeSensor: return @"Sensor";
        case HAEntityTypeBinarySensor: return @"Binary";
        case HAEntityTypeCamera: return @"Camera";
        case HAEntityTypeScript: return @"Script";
        case HAEntityTypeInputBoolean: return @"Toggle";
        default: return @"Entity";
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 1001) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 1001) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

#pragma mark - Weather Refresh Timer

- (void)startWeatherRefreshTimer {
    // Invalidate existing timer if any
    [self.weatherRefreshTimer invalidate];

    // Create timer that fires every hour (3600 seconds)
    self.weatherRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:3600.0
                                                                target:self
                                                              selector:@selector(weatherRefreshTimerFired)
                                                              userInfo:nil
                                                               repeats:YES];

    // Allow timer to fire even when scrolling
    [[NSRunLoop mainRunLoop] addTimer:self.weatherRefreshTimer forMode:NSRunLoopCommonModes];

    NSLog(@"[Dashboard] Weather refresh timer started (1 hour interval)");
}

- (void)weatherRefreshTimerFired {
    NSLog(@"[Dashboard] Weather refresh timer fired");
    [self loadWeatherDataIfNeeded];
}

- (void)loadWeatherDataIfNeeded {
    // Check if we need to fetch (no data yet, or last fetch was more than 55 minutes ago)
    BOOL needsFetch = NO;

    if (!self.forecastData || self.forecastData.count == 0) {
        needsFetch = YES;
        NSLog(@"[Dashboard] Weather fetch needed: no forecast data");
    } else if (!self.lastWeatherFetch) {
        needsFetch = YES;
        NSLog(@"[Dashboard] Weather fetch needed: no last fetch time");
    } else {
        NSTimeInterval timeSinceLastFetch = [[NSDate date] timeIntervalSinceDate:self.lastWeatherFetch];
        // Fetch if more than 55 minutes have passed (allows some buffer before the hour)
        if (timeSinceLastFetch > 55 * 60) {
            needsFetch = YES;
            NSLog(@"[Dashboard] Weather fetch needed: %.0f minutes since last fetch", timeSinceLastFetch / 60);
        }
    }

    if (needsFetch) {
        [self fetchWeatherData];
    } else {
        NSLog(@"[Dashboard] Weather fetch skipped: data is fresh");
    }
}

- (void)fetchWeatherData {
    NSLog(@"[Dashboard] fetchWeatherData called");

    // If entities not loaded yet, wait for them
    if (self.allEntities.count == 0) {
        NSLog(@"[Dashboard] No entities loaded yet, will retry after entities load");
        return;
    }

    // Find weather entity
    for (HAEntity *entity in self.allEntities) {
        if ([entity.entityId hasPrefix:@"weather."]) {
            self.weatherEntity = entity;
            NSLog(@"[Dashboard] Found weather entity: %@", entity.entityId);
            break;
        }
    }

    if (!self.weatherEntity) {
        NSLog(@"[Dashboard] No weather entity found");
        if (self.currentConditionLabel) {
            self.currentConditionLabel.text = @"No weather entity";
        }
        return;
    }

    NSLog(@"[Dashboard] Weather state: %@", self.weatherEntity.state);

    // Update current weather from entity state
    [self updateCurrentWeatherFromEntity];

    // First check if forecast is already in entity attributes (older HA versions)
    NSDictionary *attrs = self.weatherEntity.attributes;
    if (attrs[@"forecast"] && [attrs[@"forecast"] isKindOfClass:[NSArray class]]) {
        NSArray *forecast = attrs[@"forecast"];
        if (forecast.count > 0) {
            NSLog(@"[Dashboard] Found forecast in entity attributes: %lu days", (unsigned long)forecast.count);
            self.forecastData = forecast;
            self.lastWeatherFetch = [NSDate date];
            [self updateForecastView];
            return;
        }
    }

    // Fetch forecast via service call (newer HA versions)
    [[HAAPIClient sharedClient] fetchWeatherForecastForEntity:self.weatherEntity.entityId completion:^(BOOL success, id result, NSError *error) {
        NSLog(@"[Dashboard] Forecast service call - success: %d, error: %@", success, error);
        if (success && result) {
            self.lastWeatherFetch = [NSDate date];
            NSLog(@"[Dashboard] Weather data fetched at %@", self.lastWeatherFetch);
            [self processForecastResponse:result];
        } else {
            NSLog(@"[Dashboard] Weather forecast error: %@", error);
        }
    }];
}

- (void)updateCurrentWeatherFromEntity {
    if (!self.weatherEntity) return;

    HBThemeManager *theme = [HBThemeManager sharedManager];

    // Temperature from attributes (safely handle NSNumber or NSString)
    NSDictionary *attrs = self.weatherEntity.attributes;
    id tempVal = attrs[@"temperature"];
    NSString *tempStr = @"--°";
    if ([tempVal isKindOfClass:[NSNumber class]] || [tempVal isKindOfClass:[NSString class]]) {
        tempStr = [NSString stringWithFormat:@"%.0f°", [tempVal floatValue]];
    }

    // Update landscape card
    self.currentTempLabel.text = tempStr;

    // Update portrait bar
    self.portraitTempLabel.text = tempStr;

    // Condition from state
    NSString *condition = self.weatherEntity.state;
    NSString *formattedCondition = [self formatCondition:condition];
    HBIconType iconType = [self iconTypeForCondition:condition];

    // Update landscape card
    self.currentConditionLabel.text = formattedCondition;
    self.currentWeatherIcon.iconType = iconType;
    self.currentWeatherIcon.iconColor = [theme textColor];

    // Update portrait bar
    self.portraitConditionLabel.text = formattedCondition;
    self.portraitWeatherIcon.iconType = iconType;
    self.portraitWeatherIcon.iconColor = [theme textColor];

    // Get min/max and rain from today's forecast
    if (self.forecastData.count > 0 && [self.forecastData[0] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *today = self.forecastData[0];
        NSLog(@"[Weather] Today's forecast data: %@", today);

        // Safely extract numeric values
        id highTempVal = today[@"temperature"];
        id lowTempVal = today[@"templow"];
        id precipVal = today[@"precipitation"];

        CGFloat highTemp = 0, lowTemp = 0, precipitation = 0;
        BOOL hasHighTemp = NO, hasLowTemp = NO;

        if ([highTempVal isKindOfClass:[NSNumber class]] || [highTempVal isKindOfClass:[NSString class]]) {
            highTemp = [highTempVal floatValue];
            hasHighTemp = YES;
        }
        if ([lowTempVal isKindOfClass:[NSNumber class]] || [lowTempVal isKindOfClass:[NSString class]]) {
            lowTemp = [lowTempVal floatValue];
            hasLowTemp = YES;
        }
        if ([precipVal isKindOfClass:[NSNumber class]] || [precipVal isKindOfClass:[NSString class]]) {
            precipitation = [precipVal floatValue];
        }

        NSLog(@"[Weather] High: %.0f, Low: %.0f", highTemp, lowTemp);

        // Create attributed string for min/max: [grey min] [white max]
        if (hasHighTemp && hasLowTemp) {
            NSString *minStr = [NSString stringWithFormat:@"%.0f°", lowTemp];
            NSString *maxStr = [NSString stringWithFormat:@"  %.0f°", highTemp];

            NSMutableAttributedString *minMaxStr = [[NSMutableAttributedString alloc] init];

            // Min temp in grey (same size as forecast days)
            NSDictionary *greyAttrs = @{
                NSForegroundColorAttributeName: [UIColor grayColor],
                NSFontAttributeName: [UIFont boldSystemFontOfSize:26]
            };
            [minMaxStr appendAttributedString:[[NSAttributedString alloc] initWithString:minStr attributes:greyAttrs]];

            // Max temp in white (same size as forecast days)
            NSDictionary *whiteAttrs = @{
                NSForegroundColorAttributeName: [UIColor whiteColor],
                NSFontAttributeName: [UIFont boldSystemFontOfSize:26]
            };
            [minMaxStr appendAttributedString:[[NSAttributedString alloc] initWithString:maxStr attributes:whiteAttrs]];

            self.currentMinMaxLabel.attributedText = minMaxStr;
        }

        // Rain amount
        if (precipitation > 0) {
            self.currentRainLabel.text = [NSString stringWithFormat:@"%.1fmm rain", precipitation];
        } else {
            self.currentRainLabel.text = @"";
        }
    }
}

- (void)processForecastResponse:(id)response {
    NSLog(@"[Dashboard] Forecast response: %@", response);

    NSArray *forecast = nil;

    // Try multiple response formats
    if ([response isKindOfClass:[NSDictionary class]]) {
        NSDictionary *responseDict = (NSDictionary *)response;

        // Format 0: { "service_response": { "weather.entity_id": { "forecast": [...] } } } (HA 2024+)
        if (responseDict[@"service_response"]) {
            NSDictionary *serviceResponse = responseDict[@"service_response"];
            NSDictionary *entityData = serviceResponse[self.weatherEntity.entityId];
            if (entityData && entityData[@"forecast"]) {
                forecast = entityData[@"forecast"];
                NSLog(@"[Dashboard] Found forecast in format 0 (service_response wrapper)");
            }
        }

        // Format 1: { "weather.entity_id": { "forecast": [...] } }
        if (!forecast) {
            NSDictionary *entityData = responseDict[self.weatherEntity.entityId];
            if (entityData && entityData[@"forecast"]) {
                forecast = entityData[@"forecast"];
                NSLog(@"[Dashboard] Found forecast in format 1 (entity_id key)");
            }
        }

        // Format 2: { "forecast": [...] } - direct forecast array
        if (!forecast && responseDict[@"forecast"]) {
            forecast = responseDict[@"forecast"];
            NSLog(@"[Dashboard] Found forecast in format 2 (direct forecast key)");
        }

        // Format 3: Entity state response - { "attributes": { "forecast": [...] } }
        if (!forecast && responseDict[@"attributes"]) {
            NSDictionary *attrs = responseDict[@"attributes"];
            if (attrs[@"forecast"]) {
                forecast = attrs[@"forecast"];
                NSLog(@"[Dashboard] Found forecast in format 3 (entity state attributes)");
            }
        }

        // Format 4: Service call results as dict with nested entity
        if (!forecast) {
            for (NSString *key in responseDict) {
                id value = responseDict[key];
                if ([value isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *nested = (NSDictionary *)value;
                    if (nested[@"forecast"]) {
                        forecast = nested[@"forecast"];
                        NSLog(@"[Dashboard] Found forecast in format 4 (nested dict with key %@)", key);
                        break;
                    }
                }
            }
        }
    }

    // Format 5: Response is array directly
    if (!forecast && [response isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)response;
        NSLog(@"[Dashboard] Response is array with %lu items", (unsigned long)arr.count);
        if (arr.count > 0 && [arr[0] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *first = arr[0];
            // Check if it's an array of forecast days (has datetime or temperature)
            if (first[@"datetime"] || first[@"temperature"] || first[@"condition"]) {
                forecast = arr;
                NSLog(@"[Dashboard] Found forecast in format 5 (direct forecast array)");
            }
            // Or array of service results
            else if (first[@"forecast"]) {
                forecast = first[@"forecast"];
                NSLog(@"[Dashboard] Found forecast in format 5b (array of service results)");
            }
            // Or entity with attributes
            else if (first[@"attributes"]) {
                NSDictionary *attrs = first[@"attributes"];
                if (attrs[@"forecast"]) {
                    forecast = attrs[@"forecast"];
                    NSLog(@"[Dashboard] Found forecast in format 5c (array item with attributes)");
                }
            }
        }
    }

    if (!forecast || forecast.count == 0) {
        NSLog(@"[Dashboard] No forecast data found in response");
        // Try to get forecast from entity attributes as fallback
        NSDictionary *attrs = self.weatherEntity.attributes;
        if (attrs[@"forecast"]) {
            forecast = attrs[@"forecast"];
            NSLog(@"[Dashboard] Using forecast from entity attributes (fallback)");
        }
    }

    if (forecast && forecast.count > 0) {
        NSLog(@"[Dashboard] Found %lu forecast days", (unsigned long)forecast.count);
        NSLog(@"[Dashboard] First forecast day: %@", forecast[0]);
        self.forecastData = forecast;
        [self updateForecastView];
        [self updateCurrentWeatherFromEntity]; // Update min/max and rain from forecast
    } else {
        NSLog(@"[Dashboard] No forecast data available - showing message");
        // Show a message in the forecast area
        HBThemeManager *theme = [HBThemeManager sharedManager];
        UILabel *noForecastLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 300, 30)];
        noForecastLabel.text = @"Forecast unavailable";
        noForecastLabel.font = [UIFont systemFontOfSize:14];
        noForecastLabel.textColor = [theme secondaryTextColor];
        [self.forecastScrollView addSubview:noForecastLabel];
    }
}

- (void)updateForecastView {
    // Safety checks
    if (!self.forecastScrollView) {
        NSLog(@"[Dashboard] updateForecastView called but forecastScrollView is nil");
        return;
    }
    if (!self.forecastData || ![self.forecastData isKindOfClass:[NSArray class]]) {
        NSLog(@"[Dashboard] updateForecastView called but forecastData is nil or not an array");
        return;
    }

    HBThemeManager *theme = [HBThemeManager sharedManager];
    BOOL isPortrait = [self isPortraitOrientation];

    // Clear existing forecast items
    for (UIView *subview in self.forecastScrollView.subviews) {
        [subview removeFromSuperview];
    }

    CGFloat containerWidth = self.forecastScrollView.bounds.size.width;
    CGFloat containerHeight = self.forecastScrollView.bounds.size.height;
    CGFloat spacing = 12.0;
    // Less padding in portrait since forecast is in narrower right-half container
    CGFloat sidePadding = isPortrait ? 0 : 12.0;

    // Both orientations use 2x3 grid
    NSInteger columns = 3;
    NSInteger rows = 2;

    NSInteger count = MIN(self.forecastData.count, 6);
    if (count == 0) return;

    CGFloat availableWidth = containerWidth - (sidePadding * 2) - (spacing * (columns - 1));
    CGFloat itemWidth = availableWidth / columns;
    CGFloat availableHeight = containerHeight - (spacing * (rows - 1));
    CGFloat itemHeight = availableHeight / rows;

    for (NSInteger i = 0; i < count; i++) {
        id dayObj = self.forecastData[i];
        if (![dayObj isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *day = (NSDictionary *)dayObj;

        // Calculate position in grid
        NSInteger row = i / columns;
        NSInteger col = i % columns;
        CGFloat xPos = sidePadding + col * (itemWidth + spacing);
        CGFloat yPos = row * (itemHeight + spacing);

        UIView *dayView = [[UIView alloc] initWithFrame:CGRectMake(xPos, yPos, itemWidth, itemHeight)];
        dayView.backgroundColor = [theme cardBackgroundColor];
        dayView.layer.cornerRadius = 12;
        dayView.clipsToBounds = YES;
        [self.forecastScrollView addSubview:dayView];

        // Both orientations use 2x3 grid - adjust sizes based on available space
        CGFloat padding = 8.0;
        CGFloat yOffset = 8.0;
        CGFloat dayFontSize = isPortrait ? 16 : 28;
        CGFloat tempFontSize = isPortrait ? 14 : 24;
        CGFloat conditionFontSize = isPortrait ? 11 : 18;
        CGFloat iconSize = isPortrait ? 30 : 50;

        // Day name
        NSString *dateStr = day[@"datetime"];
        CGFloat dayLabelHeight = isPortrait ? 18 : 32;
        UILabel *dayLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, itemWidth - padding * 2, dayLabelHeight)];
        dayLabel.text = [self dayNameFromDateString:dateStr index:i];
        dayLabel.font = [UIFont boldSystemFontOfSize:dayFontSize];
        dayLabel.textColor = [theme textColor];
        dayLabel.textAlignment = NSTextAlignmentLeft;
        dayLabel.adjustsFontSizeToFitWidth = YES;
        dayLabel.minimumScaleFactor = 0.7;
        [dayView addSubview:dayLabel];
        yOffset += dayLabelHeight;

        // Min/Max temps on one line: [grey min] [white max]
        // Safely extract numeric values (API may return NSNumber or NSString)
        id highTempVal = day[@"temperature"];
        id lowTempVal = day[@"templow"];
        CGFloat highTemp = 0, lowTemp = 0;
        BOOL hasHighTemp = NO, hasLowTemp = NO;

        if ([highTempVal isKindOfClass:[NSNumber class]]) {
            highTemp = [highTempVal floatValue];
            hasHighTemp = YES;
        } else if ([highTempVal isKindOfClass:[NSString class]]) {
            highTemp = [highTempVal floatValue];
            hasHighTemp = YES;
        }

        if ([lowTempVal isKindOfClass:[NSNumber class]]) {
            lowTemp = [lowTempVal floatValue];
            hasLowTemp = YES;
        } else if ([lowTempVal isKindOfClass:[NSString class]]) {
            lowTemp = [lowTempVal floatValue];
            hasLowTemp = YES;
        }

        CGFloat tempLabelHeight = isPortrait ? 16 : 28;
        UILabel *tempLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, itemWidth - padding * 2, tempLabelHeight)];
        tempLabel.textAlignment = NSTextAlignmentLeft;
        tempLabel.adjustsFontSizeToFitWidth = YES;
        tempLabel.minimumScaleFactor = 0.7;

        if (hasLowTemp && hasHighTemp) {
            NSString *minStr = [NSString stringWithFormat:@"%.0f°", lowTemp];
            NSString *maxStr = [NSString stringWithFormat:@" %.0f°", highTemp];

            NSMutableAttributedString *tempAttrStr = [[NSMutableAttributedString alloc] init];

            // Min temp in grey
            NSDictionary *greyAttrs = @{
                NSForegroundColorAttributeName: [UIColor grayColor],
                NSFontAttributeName: [UIFont boldSystemFontOfSize:tempFontSize]
            };
            [tempAttrStr appendAttributedString:[[NSAttributedString alloc] initWithString:minStr attributes:greyAttrs]];

            // Max temp in white
            NSDictionary *whiteAttrs = @{
                NSForegroundColorAttributeName: [UIColor whiteColor],
                NSFontAttributeName: [UIFont boldSystemFontOfSize:tempFontSize]
            };
            [tempAttrStr appendAttributedString:[[NSAttributedString alloc] initWithString:maxStr attributes:whiteAttrs]];

            tempLabel.attributedText = tempAttrStr;
        } else if (hasHighTemp) {
            tempLabel.text = [NSString stringWithFormat:@"%.0f°", highTemp];
            tempLabel.font = [UIFont boldSystemFontOfSize:tempFontSize];
            tempLabel.textColor = [UIColor whiteColor];
        }
        [dayView addSubview:tempLabel];
        yOffset += tempLabelHeight;

        NSString *condition = day[@"condition"];

        // Condition description - show in both orientations
        CGFloat conditionLabelHeight = isPortrait ? 14 : 22;
        UILabel *conditionLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, itemWidth - padding * 2, conditionLabelHeight)];
        conditionLabel.text = [self formatCondition:condition];
        conditionLabel.font = [UIFont systemFontOfSize:conditionFontSize];
        conditionLabel.textColor = [theme secondaryTextColor];
        conditionLabel.textAlignment = NSTextAlignmentLeft;
        conditionLabel.adjustsFontSizeToFitWidth = YES;
        conditionLabel.minimumScaleFactor = 0.7;
        [dayView addSubview:conditionLabel];
        yOffset += conditionLabelHeight;

        // Rain/precipitation - show in both orientations
        id precipVal = day[@"precipitation"];
        CGFloat precipitation = 0;
        if ([precipVal isKindOfClass:[NSNumber class]] || [precipVal isKindOfClass:[NSString class]]) {
            precipitation = [precipVal floatValue];
        }
        if (precipitation > 0) {
            CGFloat rainLabelHeight = isPortrait ? 14 : 22;
            UILabel *rainLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, itemWidth - padding * 2, rainLabelHeight)];
            rainLabel.text = [NSString stringWithFormat:@"%.1fmm", precipitation];
            rainLabel.font = [UIFont systemFontOfSize:conditionFontSize];
            rainLabel.textColor = [UIColor colorWithRed:0.4 green:0.6 blue:1.0 alpha:1.0];
            rainLabel.textAlignment = NSTextAlignmentLeft;
            [dayView addSubview:rainLabel];
        }

        // Weather icon - bottom right corner
        CGFloat iconPadding = 4.0;
        HBIconView *icon = [[HBIconView alloc] initWithIconType:[self iconTypeForCondition:condition] color:[theme textColor]];
        icon.frame = CGRectMake(itemWidth - iconSize - iconPadding, itemHeight - iconSize - iconPadding, iconSize, iconSize);
        [dayView addSubview:icon];
    }

    self.forecastScrollView.contentSize = CGSizeMake(containerWidth, containerHeight);
}

- (NSString *)dayNameFromDateString:(NSString *)dateStr index:(NSInteger)index {
    if (index == 0) return @"Today";
    if (index == 1) return @"Tomorrow";

    if (!dateStr || dateStr.length < 10) {
        return @"--";
    }

    NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
    inputFormatter.dateFormat = @"yyyy-MM-dd";

    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
    outputFormatter.dateFormat = @"EEE";

    NSDate *date = [inputFormatter dateFromString:[dateStr substringToIndex:10]];
    if (date) {
        return [outputFormatter stringFromDate:date];
    }
    return @"--";
}

- (NSString *)formatCondition:(NSString *)condition {
    if (!condition) return @"Unknown";

    // Capitalize and format condition string
    NSDictionary *conditionMap = @{
        @"sunny": @"Sunny",
        @"clear-night": @"Clear",
        @"cloudy": @"Cloudy",
        @"partlycloudy": @"Partly Cloudy",
        @"rainy": @"Rainy",
        @"pouring": @"Heavy Rain",
        @"snowy": @"Snowy",
        @"snowy-rainy": @"Sleet",
        @"windy": @"Windy",
        @"fog": @"Foggy",
        @"hail": @"Hail",
        @"lightning": @"Thunderstorm",
        @"lightning-rainy": @"Thunderstorm",
        @"exceptional": @"Exceptional"
    };

    return conditionMap[condition.lowercaseString] ?: [condition capitalizedString];
}

- (HBIconType)iconTypeForCondition:(NSString *)condition {
    if (!condition) return HBIconTypeCloud;

    NSString *lowerCondition = condition.lowercaseString;

    if ([lowerCondition isEqualToString:@"sunny"] || [lowerCondition isEqualToString:@"clear-night"]) {
        return HBIconTypeSun;
    } else if ([lowerCondition isEqualToString:@"cloudy"]) {
        return HBIconTypeCloud;
    } else if ([lowerCondition isEqualToString:@"partlycloudy"]) {
        return HBIconTypePartlyCloudy;
    } else if ([lowerCondition isEqualToString:@"rainy"] || [lowerCondition isEqualToString:@"pouring"]) {
        return HBIconTypeRain;
    } else if ([lowerCondition isEqualToString:@"snowy"] || [lowerCondition isEqualToString:@"snowy-rainy"]) {
        return HBIconTypeSnow;
    } else if ([lowerCondition isEqualToString:@"lightning"] || [lowerCondition isEqualToString:@"lightning-rainy"]) {
        return HBIconTypeStorm;
    } else {
        return HBIconTypeCloud;
    }
}

#pragma mark - Room Reordering

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.roomsCollectionView];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSIndexPath *indexPath = [self.roomsCollectionView indexPathForItemAtPoint:location];
            if (!indexPath) return;

            self.draggedIndexPath = indexPath;
            UICollectionViewCell *cell = [self.roomsCollectionView cellForItemAtIndexPath:indexPath];

            // Create snapshot of the cell
            self.draggedCellSnapshot = [cell snapshotViewAfterScreenUpdates:YES];
            self.draggedCellSnapshot.center = cell.center;
            self.draggedCellSnapshot.alpha = 0.9;
            self.draggedCellSnapshot.transform = CGAffineTransformMakeScale(1.1, 1.1);
            self.draggedCellSnapshot.layer.shadowColor = [UIColor blackColor].CGColor;
            self.draggedCellSnapshot.layer.shadowOpacity = 0.3;
            self.draggedCellSnapshot.layer.shadowRadius = 5;
            self.draggedCellSnapshot.layer.shadowOffset = CGSizeMake(0, 3);
            [self.roomsCollectionView addSubview:self.draggedCellSnapshot];

            // Hide the original cell
            cell.hidden = YES;

            // Haptic feedback
            if ([UIImpactFeedbackGenerator class]) {
                UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [feedback impactOccurred];
            }
            break;
        }

        case UIGestureRecognizerStateChanged: {
            if (!self.draggedCellSnapshot) return;

            // Move snapshot to follow finger
            self.draggedCellSnapshot.center = CGPointMake(location.x, self.draggedCellSnapshot.center.y);

            // Check if we need to swap with another cell
            NSIndexPath *newIndexPath = [self.roomsCollectionView indexPathForItemAtPoint:location];
            if (newIndexPath && ![newIndexPath isEqual:self.draggedIndexPath]) {
                // Swap in data source
                [[HBRoomManager sharedManager] moveRoomFromIndex:self.draggedIndexPath.item toIndex:newIndexPath.item];

                // Move item in collection view
                [self.roomsCollectionView moveItemAtIndexPath:self.draggedIndexPath toIndexPath:newIndexPath];

                // Update dragged index path
                self.draggedIndexPath = newIndexPath;
            }
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!self.draggedIndexPath) return;

            UICollectionViewCell *cell = [self.roomsCollectionView cellForItemAtIndexPath:self.draggedIndexPath];

            [UIView animateWithDuration:0.25 animations:^{
                self.draggedCellSnapshot.center = cell.center;
                self.draggedCellSnapshot.transform = CGAffineTransformIdentity;
                self.draggedCellSnapshot.alpha = 1.0;
            } completion:^(BOOL finished) {
                cell.hidden = NO;
                [self.draggedCellSnapshot removeFromSuperview];
                self.draggedCellSnapshot = nil;
                self.draggedIndexPath = nil;
            }];
            break;
        }

        default:
            break;
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (collectionView == self.roomsCollectionView) {
        return [HBRoomManager sharedManager].rooms.count;
    } else {
        // Entities collection
        NSInteger count = self.selectedRoomLights ? self.selectedRoomLights.count : 0;
        NSLog(@"[Dashboard] numberOfItemsInSection: %ld", (long)count);
        return count;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == self.roomsCollectionView) {
        // Room tile cell
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"RoomTileCell" forIndexPath:indexPath];

        HBThemeManager *theme = [HBThemeManager sharedManager];
        HBRoom *room = [HBRoomManager sharedManager].rooms[indexPath.item];

        // Clear existing subviews
        for (UIView *subview in cell.contentView.subviews) {
            [subview removeFromSuperview];
        }

        // Style the cell as a square tile (no rounding)
        cell.contentView.layer.cornerRadius = 0;
        cell.contentView.clipsToBounds = YES;

        // Highlight selected room
        BOOL isSelected = [room isEqual:self.selectedRoom];
        UIColor *iconColor = isSelected ? [UIColor blackColor] : [theme textColor];

        // Icon view (centered)
        HBIconView *iconView = [[HBIconView alloc] initWithIconType:(HBIconType)room.iconType color:iconColor];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:iconView];

        // Name label (below icon)
        UILabel *nameLabel = [[UILabel alloc] init];
        nameLabel.text = room.name;
        nameLabel.font = [UIFont systemFontOfSize:11];
        nameLabel.textAlignment = NSTextAlignmentCenter;
        nameLabel.numberOfLines = 2;
        nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:nameLabel];

        if (isSelected) {
            cell.contentView.backgroundColor = [theme onColor];
            nameLabel.textColor = [UIColor blackColor];
        } else {
            cell.contentView.backgroundColor = [theme cardBackgroundColor];
            nameLabel.textColor = [theme textColor];
        }

        [NSLayoutConstraint activateConstraints:@[
            [iconView.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor constant:-8],
            [iconView.widthAnchor constraintEqualToConstant:36],
            [iconView.heightAnchor constraintEqualToConstant:36],
            [nameLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:2],
            [nameLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:4],
            [nameLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-4],
        ]];

        return cell;
    } else {
        // Entities (lights) cell
        NSLog(@"[Dashboard] cellForItemAtIndexPath: %ld", (long)indexPath.item);

        HBLightToggleCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"LightCell" forIndexPath:indexPath];

        // Defensive bounds check
        if (!self.selectedRoomLights || indexPath.item >= (NSInteger)self.selectedRoomLights.count) {
            NSLog(@"[Dashboard] ERROR: indexPath.item %ld out of bounds (count: %lu)",
                  (long)indexPath.item, (unsigned long)(self.selectedRoomLights ? self.selectedRoomLights.count : 0));
            return cell;
        }

        HAEntity *light = self.selectedRoomLights[indexPath.item];
        if (!light) {
            NSLog(@"[Dashboard] ERROR: light is nil at index %ld", (long)indexPath.item);
            return cell;
        }

        NSLog(@"[Dashboard] Configuring cell for entity: %@", light.entityId);
        cell.delegate = self;
        [cell configureWithEntity:light];

        return cell;
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == self.roomsCollectionView) {
        // Fixed size for room tiles
        return CGSizeMake(kRoomTileSize, kRoomTileSize);
    } else {
        // Determine columns based on orientation: 5 in landscape, 3 in portrait
        CGFloat width = self.contentView.bounds.size.width;
        CGFloat height = self.contentView.bounds.size.height;
        BOOL isLandscape = width > height;
        NSInteger columns = isLandscape ? 5 : 3;

        CGFloat spacing = 12.0;
        CGFloat padding = 12.0;
        CGFloat availableWidth = width - (padding * 2) - (spacing * (columns - 1));
        CGFloat cellSize = availableWidth / columns;
        return CGSizeMake(cellSize, cellSize);
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == self.roomsCollectionView) {
        NSLog(@"[Dashboard] didSelectItemAtIndexPath (room): %ld", (long)indexPath.item);

        NSArray *rooms = [HBRoomManager sharedManager].rooms;
        if (!rooms || indexPath.item >= (NSInteger)rooms.count) {
            NSLog(@"[Dashboard] ERROR: indexPath.item %ld out of bounds (rooms count: %lu)",
                  (long)indexPath.item, (unsigned long)(rooms ? rooms.count : 0));
            return;
        }

        self.isHomeSelected = NO;
        self.selectedRoom = rooms[indexPath.item];
        NSLog(@"[Dashboard] Selected room: %@", self.selectedRoom.name);
        [self updateHomeButtonAppearance];
        [self.roomsCollectionView reloadData];
        [self updateSelectedRoomDisplay];
    }
}

#pragma mark - Room Entity Reordering

- (void)handleRoomEntityLongPress:(UILongPressGestureRecognizer *)gesture {
    CGPoint locationInCollection = [gesture locationInView:self.entitiesCollectionView];
    CGPoint locationInContentView = [gesture locationInView:self.contentView];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSIndexPath *indexPath = [self.entitiesCollectionView indexPathForItemAtPoint:locationInCollection];
            if (indexPath) {
                self.isDraggingEntity = YES; // Prevent UI refresh during drag
                self.draggingRoomEntityIndexPath = indexPath;
                self.draggedIndexPath = indexPath;

                // Create snapshot of the cell for dragging
                UICollectionViewCell *cell = [self.entitiesCollectionView cellForItemAtIndexPath:indexPath];
                if (cell) {
                    // Create snapshot view
                    self.draggedCellSnapshot = [cell snapshotViewAfterScreenUpdates:YES];
                    self.draggedCellSnapshot.frame = [self.contentView convertRect:cell.frame fromView:self.entitiesCollectionView];
                    self.draggedCellSnapshot.alpha = 0.9;
                    self.draggedCellSnapshot.layer.shadowColor = [UIColor blackColor].CGColor;
                    self.draggedCellSnapshot.layer.shadowOffset = CGSizeMake(0, 4);
                    self.draggedCellSnapshot.layer.shadowRadius = 8;
                    self.draggedCellSnapshot.layer.shadowOpacity = 0.3;
                    [self.contentView addSubview:self.draggedCellSnapshot];

                    // Hide original cell
                    cell.hidden = YES;

                    // Animate snapshot lift
                    [UIView animateWithDuration:0.2 animations:^{
                        self.draggedCellSnapshot.transform = CGAffineTransformMakeScale(1.05, 1.05);
                    }];
                }
                // Show bin button
                [self showBinButton];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.draggedCellSnapshot) {
                // Move snapshot to follow finger
                self.draggedCellSnapshot.center = locationInContentView;

                // Check if dragging over bin
                BOOL overBin = CGRectContainsPoint(self.binButton.frame, locationInContentView);
                [self updateBinButtonHighlight:overBin];

                // Update target position for reordering within collection
                if (!overBin) {
                    NSIndexPath *targetIndexPath = [self.entitiesCollectionView indexPathForItemAtPoint:locationInCollection];
                    if (targetIndexPath && ![targetIndexPath isEqual:self.draggedIndexPath]) {
                        // Move item in collection view
                        [self.entitiesCollectionView moveItemAtIndexPath:self.draggedIndexPath toIndexPath:targetIndexPath];

                        // Update data model
                        NSMutableArray *mutableLights = [self.selectedRoomLights mutableCopy];
                        HAEntity *movedEntity = mutableLights[self.draggedIndexPath.item];
                        [mutableLights removeObjectAtIndex:self.draggedIndexPath.item];
                        [mutableLights insertObject:movedEntity atIndex:targetIndexPath.item];
                        self.selectedRoomLights = [mutableLights copy];

                        self.draggedIndexPath = targetIndexPath;
                    }
                }
            }
            break;
        }
        case UIGestureRecognizerStateEnded: {
            BOOL droppedOnBin = CGRectContainsPoint(self.binButton.frame, locationInContentView);

            if (droppedOnBin && self.draggingRoomEntityIndexPath) {
                // Remove snapshot with animation
                [UIView animateWithDuration:0.2 animations:^{
                    self.draggedCellSnapshot.alpha = 0;
                    self.draggedCellSnapshot.transform = CGAffineTransformMakeScale(0.5, 0.5);
                } completion:^(BOOL finished) {
                    [self.draggedCellSnapshot removeFromSuperview];
                    self.draggedCellSnapshot = nil;
                }];
                // Delete the entity (use current draggedIndexPath which may have moved)
                [self deleteRoomEntityAtIndexPath:self.draggedIndexPath];
            } else {
                // Animate snapshot back to cell position and remove
                UICollectionViewCell *cell = [self.entitiesCollectionView cellForItemAtIndexPath:self.draggedIndexPath];
                CGRect targetFrame = cell ? [self.contentView convertRect:cell.frame fromView:self.entitiesCollectionView] : self.draggedCellSnapshot.frame;

                [UIView animateWithDuration:0.2 animations:^{
                    self.draggedCellSnapshot.frame = targetFrame;
                    self.draggedCellSnapshot.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished) {
                    [self.draggedCellSnapshot removeFromSuperview];
                    self.draggedCellSnapshot = nil;
                    // Show the cell again
                    if (cell) cell.hidden = NO;
                }];

                // Save the new order
                NSMutableArray *newEntityIds = [NSMutableArray array];
                for (HAEntity *entity in self.selectedRoomLights) {
                    [newEntityIds addObject:entity.entityId];
                }
                self.selectedRoom.entityIds = newEntityIds;
                [[HBRoomManager sharedManager] updateRoom:self.selectedRoom];
            }

            // Hide bin button and allow UI refresh again
            [self hideBinButton];
            self.isDraggingEntity = NO;
            self.draggingRoomEntityIndexPath = nil;
            self.draggedIndexPath = nil;
            break;
        }
        default: {
            // Cancel - animate snapshot back
            if (self.draggedCellSnapshot) {
                UICollectionViewCell *cell = [self.entitiesCollectionView cellForItemAtIndexPath:self.draggedIndexPath];
                [UIView animateWithDuration:0.2 animations:^{
                    self.draggedCellSnapshot.alpha = 0;
                } completion:^(BOOL finished) {
                    [self.draggedCellSnapshot removeFromSuperview];
                    self.draggedCellSnapshot = nil;
                    if (cell) cell.hidden = NO;
                }];
            }
            // Hide bin button and allow UI refresh again
            [self hideBinButton];
            self.isDraggingEntity = NO;
            self.draggingRoomEntityIndexPath = nil;
            self.draggedIndexPath = nil;
            break;
        }
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath {
    // Only allow moving entities in the room collection view
    return collectionView == self.entitiesCollectionView;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (collectionView != self.entitiesCollectionView) return;
    if (!self.selectedRoom) return;

    // Get the entity being moved
    HAEntity *movedEntity = self.selectedRoomLights[sourceIndexPath.item];

    // Update the local array
    NSMutableArray *mutableLights = [self.selectedRoomLights mutableCopy];
    [mutableLights removeObjectAtIndex:sourceIndexPath.item];
    [mutableLights insertObject:movedEntity atIndex:destinationIndexPath.item];
    self.selectedRoomLights = [mutableLights copy];

    // Update the room's entityIds to match the new order
    NSMutableArray *newEntityIds = [NSMutableArray array];
    for (HAEntity *entity in self.selectedRoomLights) {
        [newEntityIds addObject:entity.entityId];
    }
    self.selectedRoom.entityIds = newEntityIds;
    [[HBRoomManager sharedManager] updateRoom:self.selectedRoom];

    NSLog(@"[Dashboard] Reordered room entities: %@", newEntityIds);
}

#pragma mark - Bin Button for Room Entity Deletion

- (void)showBinButton {
    self.binButton.hidden = NO;
    self.isDraggingOverBin = NO;
    self.binButton.layer.borderColor = [UIColor clearColor].CGColor;
    [UIView animateWithDuration:0.2 animations:^{
        self.binButton.alpha = 1.0;
    }];
}

- (void)hideBinButton {
    [UIView animateWithDuration:0.2 animations:^{
        self.binButton.alpha = 0;
    } completion:^(BOOL finished) {
        self.binButton.hidden = YES;
        self.binButton.layer.borderColor = [UIColor clearColor].CGColor;
    }];
}

- (void)updateBinButtonHighlight:(BOOL)isOver {
    if (isOver != self.isDraggingOverBin) {
        self.isDraggingOverBin = isOver;
        HBThemeManager *theme = [HBThemeManager sharedManager];
        UIColor *borderColor = isOver ? [UIColor redColor] : [UIColor clearColor];
        UIColor *bgColor = isOver ? [[UIColor redColor] colorWithAlphaComponent:0.2] : [theme cardBackgroundColor];
        [UIView animateWithDuration:0.15 animations:^{
            self.binButton.layer.borderColor = borderColor.CGColor;
            self.binButton.backgroundColor = bgColor;
        }];
    }
}

- (void)deleteRoomEntityAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.selectedRoom || indexPath.item >= self.selectedRoomLights.count) return;

    HAEntity *entityToDelete = self.selectedRoomLights[indexPath.item];
    NSLog(@"[Dashboard] Deleting entity from room: %@", entityToDelete.entityId);

    // Update the local array
    NSMutableArray *mutableLights = [self.selectedRoomLights mutableCopy];
    [mutableLights removeObjectAtIndex:indexPath.item];
    self.selectedRoomLights = [mutableLights copy];

    // Update the room's entityIds
    NSMutableArray *newEntityIds = [NSMutableArray array];
    for (HAEntity *entity in self.selectedRoomLights) {
        [newEntityIds addObject:entity.entityId];
    }
    self.selectedRoom.entityIds = newEntityIds;
    [[HBRoomManager sharedManager] updateRoom:self.selectedRoom];

    // Reload collection view with animation
    [self.entitiesCollectionView performBatchUpdates:^{
        [self.entitiesCollectionView deleteItemsAtIndexPaths:@[indexPath]];
    } completion:nil];
}

#pragma mark - Home Sensor Reordering

- (void)handleHomeSensorLongPress:(UILongPressGestureRecognizer *)gesture {
    UIView *card = gesture.view;
    CGPoint locationInPanel = [gesture locationInView:self.sensorsPanel];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            self.isDraggingEntity = YES; // Prevent UI refresh during drag
            self.draggingSensorView = card;
            self.draggingSensorIndex = card.tag;
            self.currentPreviewIndex = card.tag;
            self.dragStartCenter = card.center;

            // Store original frames of all cards
            self.originalCardCenters = [NSMutableArray array];
            for (UIView *cardView in self.sensorCardViews) {
                [self.originalCardCenters addObject:[NSValue valueWithCGPoint:cardView.center]];
            }

            // Create drop placeholder with dashed border
            [self createDropPlaceholderWithFrame:card.frame];

            // Bring dragged card to front and add visual feedback
            [self.sensorsPanel bringSubviewToFront:card];
            [UIView animateWithDuration:0.2 animations:^{
                card.transform = CGAffineTransformMakeScale(1.05, 1.05);
                card.alpha = 0.9;
                card.layer.shadowColor = [UIColor blackColor].CGColor;
                card.layer.shadowOffset = CGSizeMake(0, 4);
                card.layer.shadowRadius = 8;
                card.layer.shadowOpacity = 0.3;
            }];
            // Show home bin button
            [self showHomeBinButton];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.draggingSensorView) {
                self.draggingSensorView.center = locationInPanel;

                // Calculate target index
                NSInteger targetIndex = [self findTargetIndexForLocation:locationInPanel];
                if (targetIndex < 0) targetIndex = self.draggingSensorIndex;

                // Update placeholder position if target changed
                if (targetIndex != self.currentPreviewIndex) {
                    self.currentPreviewIndex = targetIndex;
                    [self updateDropPlaceholderToIndex:targetIndex];
                }

                // Check if dragging over bin
                BOOL overBin = CGRectContainsPoint(self.homeBinButton.frame, locationInPanel);
                [self updateHomeBinButtonHighlight:overBin];
            }
            break;
        }
        case UIGestureRecognizerStateEnded: {
            if (!self.draggingSensorView) break;

            NSInteger targetIndex = self.currentPreviewIndex;
            NSInteger sensorIndex = self.draggingSensorIndex;

            // Check if dropped on bin
            BOOL droppedOnBin = CGRectContainsPoint(self.homeBinButton.frame, locationInPanel);

            // Remove placeholder
            [self removeDropPlaceholder];

            if (droppedOnBin) {
                // Delete the sensor
                [self deleteHomeSensorAtIndex:sensorIndex];
            } else if (targetIndex != sensorIndex && targetIndex >= 0) {
                // Reorder
                [self reorderHomeSensorFromIndex:sensorIndex toIndex:targetIndex];
            } else {
                // Animate back to original position
                [UIView animateWithDuration:0.3 animations:^{
                    self.draggingSensorView.center = self.dragStartCenter;
                    self.draggingSensorView.transform = CGAffineTransformIdentity;
                    self.draggingSensorView.alpha = 1.0;
                    self.draggingSensorView.layer.shadowOpacity = 0;
                }];
            }

            // Hide home bin button and allow UI refresh again
            [self hideHomeBinButton];
            self.isDraggingEntity = NO;
            self.draggingSensorView = nil;
            self.originalCardCenters = nil;
            break;
        }
        default: {
            // Cancel - animate back
            if (self.draggingSensorView) {
                [self removeDropPlaceholder];
                [UIView animateWithDuration:0.3 animations:^{
                    self.draggingSensorView.center = self.dragStartCenter;
                    self.draggingSensorView.transform = CGAffineTransformIdentity;
                    self.draggingSensorView.alpha = 1.0;
                    self.draggingSensorView.layer.shadowOpacity = 0;
                }];
                // Hide home bin button and allow UI refresh again
                [self hideHomeBinButton];
                self.isDraggingEntity = NO;
                self.draggingSensorView = nil;
                self.originalCardCenters = nil;
            }
            break;
        }
    }
}

- (void)animateCardsToPreviewPosition:(NSInteger)targetIndex {
    if (!self.originalCardCenters || self.originalCardCenters.count == 0) return;

    NSInteger fromIndex = self.draggingSensorIndex;

    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        for (NSInteger i = 0; i < self.sensorCardViews.count; i++) {
            UIView *cardView = self.sensorCardViews[i];

            // Skip the dragging card
            if (cardView == self.draggingSensorView) continue;

            // Calculate where this card should be displayed
            NSInteger displayPosition = i;

            if (fromIndex < targetIndex) {
                // Dragging right/down: cards between from and target shift left/up
                if (i > fromIndex && i <= targetIndex) {
                    displayPosition = i - 1;
                }
            } else if (fromIndex > targetIndex) {
                // Dragging left/up: cards between target and from shift right/down
                if (i >= targetIndex && i < fromIndex) {
                    displayPosition = i + 1;
                }
            }

            // Get the center for the display position
            if (displayPosition >= 0 && displayPosition < self.originalCardCenters.count) {
                CGPoint newCenter = [self.originalCardCenters[displayPosition] CGPointValue];
                cardView.center = newCenter;
            }
        }
    } completion:nil];
}

- (void)animateCardsToOriginalPositions {
    if (!self.originalCardCenters) return;

    [UIView animateWithDuration:0.25 animations:^{
        for (NSInteger i = 0; i < self.sensorCardViews.count; i++) {
            if (i < self.originalCardCenters.count) {
                UIView *cardView = self.sensorCardViews[i];
                if (cardView != self.draggingSensorView) {
                    cardView.center = [self.originalCardCenters[i] CGPointValue];
                }
            }
        }
    }];
}

- (NSInteger)findTargetIndexForLocation:(CGPoint)location {
    // Find which card the location is over
    for (UIView *card in self.sensorCardViews) {
        if (card == self.draggingSensorView) continue;
        if (CGRectContainsPoint(card.frame, location)) {
            return card.tag;
        }
    }
    return -1;
}

- (void)createDropPlaceholderWithFrame:(CGRect)frame {
    // Remove any existing placeholder
    [self removeDropPlaceholder];

    // Create placeholder view
    self.dropPlaceholderView = [[UIView alloc] initWithFrame:frame];
    self.dropPlaceholderView.backgroundColor = [UIColor clearColor];
    self.dropPlaceholderView.layer.cornerRadius = 12;

    // Create dashed border layer
    self.dropPlaceholderBorder = [CAShapeLayer layer];
    self.dropPlaceholderBorder.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    self.dropPlaceholderBorder.fillColor = [UIColor colorWithWhite:1.0 alpha:0.05].CGColor;
    self.dropPlaceholderBorder.lineDashPattern = @[@8, @4];
    self.dropPlaceholderBorder.lineWidth = 2.0;
    self.dropPlaceholderBorder.frame = self.dropPlaceholderView.bounds;
    self.dropPlaceholderBorder.path = [UIBezierPath bezierPathWithRoundedRect:self.dropPlaceholderView.bounds cornerRadius:12].CGPath;
    [self.dropPlaceholderView.layer addSublayer:self.dropPlaceholderBorder];

    // Insert below the dragging card
    [self.sensorsPanel insertSubview:self.dropPlaceholderView belowSubview:self.draggingSensorView];
}

- (void)updateDropPlaceholderToIndex:(NSInteger)targetIndex {
    if (!self.dropPlaceholderView || !self.originalCardCenters) return;
    if (targetIndex < 0 || targetIndex >= (NSInteger)self.originalCardCenters.count) return;

    CGPoint targetCenter = [self.originalCardCenters[targetIndex] CGPointValue];

    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.dropPlaceholderView.center = targetCenter;
    } completion:nil];
}

- (void)removeDropPlaceholder {
    if (self.dropPlaceholderView) {
        [self.dropPlaceholderView removeFromSuperview];
        self.dropPlaceholderView = nil;
        self.dropPlaceholderBorder = nil;
    }
}

- (void)reorderHomeSensorFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {
    if (fromIndex < 0 || fromIndex >= (NSInteger)self.homeSensorIds.count) return;
    if (toIndex < 0 || toIndex >= (NSInteger)self.homeSensorIds.count) return;

    // Reorder the array
    NSString *movedId = self.homeSensorIds[fromIndex];
    [self.homeSensorIds removeObjectAtIndex:fromIndex];
    [self.homeSensorIds insertObject:movedId atIndex:toIndex];

    // Save and refresh
    [self saveHomeSensorIds];
    [self updateSensorsPanel];

    NSLog(@"[Dashboard] Reordered home sensors from %ld to %ld", (long)fromIndex, (long)toIndex);
}

#pragma mark - Home Bin Button for Sensor Deletion

- (void)showHomeBinButton {
    self.homeBinButton.hidden = NO;
    self.isHomeDraggingOverBin = NO;
    self.homeBinButton.layer.borderColor = [UIColor clearColor].CGColor;
    [UIView animateWithDuration:0.2 animations:^{
        self.homeBinButton.alpha = 1.0;
    }];
}

- (void)hideHomeBinButton {
    [UIView animateWithDuration:0.2 animations:^{
        self.homeBinButton.alpha = 0;
    } completion:^(BOOL finished) {
        self.homeBinButton.hidden = YES;
        self.homeBinButton.layer.borderColor = [UIColor clearColor].CGColor;
    }];
}

- (void)updateHomeBinButtonHighlight:(BOOL)isOver {
    if (isOver != self.isHomeDraggingOverBin) {
        self.isHomeDraggingOverBin = isOver;
        HBThemeManager *theme = [HBThemeManager sharedManager];
        UIColor *borderColor = isOver ? [UIColor redColor] : [UIColor clearColor];
        UIColor *bgColor = isOver ? [[UIColor redColor] colorWithAlphaComponent:0.2] : [theme cardBackgroundColor];
        [UIView animateWithDuration:0.15 animations:^{
            self.homeBinButton.layer.borderColor = borderColor.CGColor;
            self.homeBinButton.backgroundColor = bgColor;
        }];
    }
}

- (void)deleteHomeSensorAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.homeSensorIds.count) return;

    NSString *sensorId = self.homeSensorIds[index];
    NSLog(@"[Dashboard] Deleting home sensor: %@", sensorId);

    // Remove from array
    [self.homeSensorIds removeObjectAtIndex:index];

    // Save and refresh
    [self saveHomeSensorIds];

    // Animate removal of the card
    if (index < (NSInteger)self.sensorCardViews.count) {
        UIView *cardToRemove = self.sensorCardViews[index];
        [UIView animateWithDuration:0.3 animations:^{
            cardToRemove.alpha = 0;
            cardToRemove.transform = CGAffineTransformMakeScale(0.5, 0.5);
        } completion:^(BOOL finished) {
            [cardToRemove removeFromSuperview];
            [self updateSensorsPanel];
        }];
    } else {
        [self updateSensorsPanel];
    }
}

#pragma mark - HBLightToggleCellDelegate

- (void)lightToggleCell:(HBLightToggleCell *)cell didToggleEntity:(HAEntity *)entity toState:(BOOL)on {
    // Use entityId from cell - it's always available even if entity was deallocated
    NSString *entityId = cell.entityId;
    NSLog(@"[Dashboard] didToggleEntity called, entityId: %@, toState: %d", entityId, on);

    if (!entityId) {
        NSLog(@"[Dashboard] entityId is nil, returning");
        return;
    }

    // Find the current entity in our data if needed for UI updates
    // The entity passed in might be nil (weak reference was deallocated)
    HAEntity *currentEntity = nil;
    for (HAEntity *e in self.selectedRoomLights) {
        if ([e.entityId isEqualToString:entityId]) {
            currentEntity = e;
            break;
        }
    }

    // Update local state if we found the entity
    if (currentEntity) {
        currentEntity.state = on ? @"on" : @"off";
        NSLog(@"[Dashboard] entity.state updated to: %@", currentEntity.state);

        // Update the cell directly - we're already on main thread from the tap gesture
        if (cell) {
            [cell configureWithEntity:currentEntity];
        }
    }

    [self updateAllOnOffButtonStates];

    // Make the API call - no callback handling to avoid accessing potentially-stale entity
    NSLog(@"[Dashboard] calling API, on=%d", on);

    if (on) {
        [[HAAPIClient sharedClient] turnOnEntity:entityId completion:nil];
    } else {
        [[HAAPIClient sharedClient] turnOffEntity:entityId completion:nil];
    }
    NSLog(@"[Dashboard] didToggleEntity returning");
}

- (void)lightToggleCell:(HBLightToggleCell *)cell didSetBrightness:(NSInteger)brightness forEntity:(HAEntity *)entity {
    // Use entityId from cell - it's always available even if entity was deallocated
    NSString *entityId = cell.entityId;
    if (!entityId) return;

    // Clamp to 1% minimum (use toggle to turn off)
    if (brightness < 1) brightness = 1;

    // Convert 1-100 to 3-255 for Home Assistant
    // Use ceiling to ensure 1% → 3 (not 2, which rounds back to 0%)
    NSInteger haBrightness = (brightness * 255 + 99) / 100;
    if (haBrightness < 3) haBrightness = 3; // Ensure minimum of 3 (1%)

    // Find the current entity in our data
    HAEntity *currentEntity = nil;
    for (HAEntity *e in self.selectedRoomLights) {
        if ([e.entityId isEqualToString:entityId]) {
            currentEntity = e;
            break;
        }
    }

    // Update local state if we found the entity
    if (currentEntity) {
        NSMutableDictionary *newAttrs = currentEntity.attributes ? [currentEntity.attributes mutableCopy] : [NSMutableDictionary dictionary];
        newAttrs[@"brightness"] = @(haBrightness);
        currentEntity.attributes = newAttrs;
        if (brightness > 0) {
            currentEntity.state = @"on";
        }

        // Update UI immediately
        if (cell) {
            [cell configureWithEntity:currentEntity];
        }
    }

    [self updateAllOnOffButtonStates];

    // Make API call without callback
    [[HAAPIClient sharedClient] setLightBrightness:entityId brightness:haBrightness completion:nil];
}

- (void)lightToggleCell:(HBLightToggleCell *)cell didTriggerScript:(HAEntity *)entity {
    // Use entityId from cell - it's always available even if entity was deallocated
    NSString *entityId = cell.entityId;
    NSLog(@"[Dashboard] didTriggerScript called, entityId: %@", entityId);

    if (!entityId) {
        NSLog(@"[Dashboard] entityId is nil, returning");
        return;
    }

    // Trigger the script - scripts use turn_on to execute
    [[HAAPIClient sharedClient] turnOnEntity:entityId completion:^(BOOL success, id result, NSError *error) {
        if (success) {
            NSLog(@"[Dashboard] Script triggered successfully: %@", entityId);
        } else {
            NSLog(@"[Dashboard] Script trigger failed: %@, error: %@", entityId, error);
        }
    }];
}

@end
